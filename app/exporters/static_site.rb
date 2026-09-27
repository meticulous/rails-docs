require "fileutils"
require "digest"
require "resolv"

# Builds the whole site as static files. Every page is requested from the
# app in-process (Rack, no HTTP server) and the response written to disk,
# so the output is exactly what the live app serves — same routes, views
# and presenters, no second renderer to keep in sync.
#
# Diffs, search, and legacy sdoc redirects stay dynamic: the generated
# nginx config serves everything else from disk and proxies those paths
# to the Rails app at `upstream`.
#
#   out/
#     public/       document root
#     nginx.conf    server block for it
#     failures.txt  pages that didn't render (only when there are any)
class StaticSite
  Page = Data.define(:url, :file, :status) do
    def initialize(url:, file:, status: 200) = super
  end

  # Per-request tokens Rails puts in every page. Meaningless in a static
  # file (no session to check a CSRF token against, no per-response CSP
  # header to match a nonce) and they'd make every build differ from the
  # last. The generated CSP allows the inline scripts by hash instead.
  CSRF_META = /^\s*<meta name="csrf-(?:param|token)"[^>]*>\n/
  NONCE = / nonce="[^"]*"/
  CSP_NONCE_META = /<meta name="csp-nonce" content="[^"]*"/
  INLINE_SCRIPT = %r{<script(?![^>]*\bsrc=)(?![^>]*application/ld\+json)[^>]*>(.*?)</script>}m

  attr_reader :out_dir, :host, :upstream, :resolver, :jobs, :channels

  def initialize(out_dir, host:, upstream: nil, resolver: nil, jobs: 1, channels: nil)
    @out_dir = out_dir.to_s
    @host = host
    @upstream = upstream
    @resolver = resolver
    @jobs = jobs
    @channels = channels

    if upstream && resolver.nil? && !URI(upstream).host.match?(Resolv::AddressRegex)
      raise ArgumentError, "nginx needs a resolver to look up #{upstream} per request"
    end
  end

  # Yields each package version with its Tally as it finishes (from the
  # worker process, when forked).
  def build(&progress)
    Rails.logger.silence(Logger::WARN) do
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      FileUtils.rm_rf([ public_dir, failures_path ])
      FileUtils.mkdir_p(public_dir)
      copy_public_files
      style_nonce # before forking, so every worker writes the same one

      tally = write(site_pages)
      version_tallies = in_parallel(package_versions) do |pv|
        write(version_pages(pv)).tap { |t| progress&.call(pv, t) }
      end
      version_tallies.each { |t| tally.merge!(t) }

      File.write(File.join(out_dir, "nginx.conf"), nginx_conf(tally.script_hashes))
      File.write(failures_path, tally.failures.join("\n")) if tally.failures.any?
      tally.elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
      tally
    end
  end

  def public_dir
    File.join(out_dir, "public")
  end

  def failures_path
    File.join(out_dir, "failures.txt")
  end

  private

  def site_pages
    [
      Page.new(url: "/", file: "/index.html"),
      Page.new(url: "/ecosystem", file: "/ecosystem.html"),
      Page.new(url: "/llms.txt", file: "/llms.txt"),
      Page.new(url: "/sitemap.xml", file: "/sitemap.xml"),
      Page.new(url: "/404", file: "/404.html", status: 404),
      Page.new(url: "/500", file: "/500.html", status: 500),
      *rails.frameworks.map { |f| Page.new(url: "/feeds/#{f.slug}", file: "/feeds/#{f.slug}.atom") },
      *Source.all.select(&:current_stable).map { |s| Page.new(url: "/feeds/sources/#{s.slug}", file: "/feeds/sources/#{s.slug}.atom") }
    ]
  end

  def version_pages(pv)
    return to_enum(:version_pages, pv) unless block_given?

    base = version_base(pv)
    nav = "/_nav/#{pv.source.slug}/#{segment(pv)}"

    yield Page.new(url: base, file: "#{base}/index.html")
    yield Page.new(url: "#{base}/sitemap.xml", file: "#{base}/sitemap.xml")
    yield Page.new(url: nav, file: "#{nav}.html")
    yield Page.new(url: "#{nav}/ecosystem", file: "#{nav}/ecosystem.html") if pv.source == rails

    pv.entity_versions.includes(:entity_identity).find_each do |ev|
      identity = ev.entity_identity
      path = "#{base}/#{identity.entity_url_path}"

      yield Page.new(url: path, file: "#{path}.html")
      yield Page.new(url: "#{path}.md", file: "#{path}.md")
      yield Page.new(url: "#{path}.json", file: "#{path}.json")
      if identity.kind == "method"
        og = "#{base}/og/#{identity.entity_url_path}"
        yield Page.new(url: og, file: "#{og}.svg")
      end
    end
  end

  def write(pages)
    Tally.new.tap do |tally|
      pages.each do |page|
        response = fetch(page)
        if response.status == page.status
          save(page, response.body, response.media_type, tally)
        else
          tally.failed(page, response.status)
        end
      end
    end
  end

  def save(page, body, media_type, tally)
    if media_type == "text/html"
      body = body.gsub(CSRF_META, "").gsub(NONCE, "")
                 .sub(CSP_NONCE_META, %(<meta name="csp-nonce" content="#{style_nonce}"))
      body.scan(INLINE_SCRIPT) { |(script)| tally.script_hashes << Digest::SHA256.base64digest(script) }
    end

    path = File.join(public_dir, page.file)
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, body)
    tally.wrote(body.bytesize)
  end

  # Escaped the way route helpers escape the links pointing here; the
  # file keeps the raw name, which is what nginx looks up. Error pages go
  # straight to the router, as exceptions_app sends them in production —
  # through the full stack, ActionDispatch::Static would answer /404 with
  # the stock public/404.html.
  def fetch(page)
    env = Rack::MockRequest.env_for(
      ActionDispatch::Journey::Router::Utils.escape_path(page.url),
      "HTTP_HOST" => host, "HTTPS" => "on"
    )
    app = page.status >= 400 ? Rails.application.routes : Rails.application
    status, headers, body = app.call(env)
    Rack::MockResponse.new(status, headers, body)
  ensure
    # MockResponse buffers and closes the body; this covers it raising
    # first, which would otherwise leave the request's executor open.
    body.close if body.respond_to?(:close)
  end

  # One forked worker per package version, `jobs` at a time. Rendering
  # is CPU-bound Ruby, so processes, not threads. Children get fresh
  # database connections (Active Record discards inherited pools on
  # fork) and hand their Tally back as JSON in a file. Workers leave with
  # exit!, success or not, so the parent's at_exit hooks never run twice.
  # One failure stops the build.
  def in_parallel(items)
    return items.map { |item| yield item } if jobs <= 1

    queue, running, results = items.dup, Set.new, []
    until queue.empty? && running.empty?
      while running.size < jobs && (item = queue.shift)
        running << fork do
          File.write(tally_path(Process.pid), yield(item).to_h.to_json)
          exit!(0)
        rescue Exception => e # rubocop:disable Lint/RescueException
          warn e.full_message
          exit!(1)
        end
      end

      pid, status = Process.wait2
      running.delete(pid)
      unless status.success?
        running.each { |sibling| Process.kill("TERM", sibling) }
        Process.waitall
        FileUtils.rm_f(Dir[tally_path("*")])
        raise "export worker #{pid} failed: #{status.inspect}"
      end
      results << Tally.new(**JSON.parse(File.read(tally_path(pid)), symbolize_names: true))
      File.delete(tally_path(pid))
    end
    results
  end

  def tally_path(pid)
    File.join(out_dir, ".tally-#{pid}")
  end

  # Largest versions first so the long poles start early.
  def package_versions
    versions = PackageVersion.where.not(ingested_at: nil).includes(:source)
    versions = versions.where(channel: channels) if channels
    sizes = EntityVersion.group(:package_version_id).count
    versions.sort_by { |pv| -sizes.fetch(pv.id, 0) }
  end

  def copy_public_files
    FileUtils.cp_r("#{Rails.public_path}/.", public_dir)
    compile_assets unless File.exist?(File.join(public_dir, "assets/.manifest.json"))
  end

  # Production images ship precompiled public/assets (copied above);
  # development and test compile straight into the export rather than
  # into the app's own public/, where they'd shadow live asset changes.
  def compile_assets
    assets = Rails.application.assets
    Propshaft::Processor.new(
      load_path: assets.load_path,
      output_path: Pathname(public_dir).join("assets"),
      compilers: assets.compilers,
      manifest_path: Pathname(public_dir).join("assets/.manifest.json")
    ).process
  end

  def nginx_conf(script_hashes)
    ERB.new(File.read(File.expand_path("static_site/nginx.conf.erb", __dir__)), trim_mode: "-").result_with_hash(
      root: File.expand_path(public_dir),
      upstream: upstream,
      resolver: resolver,
      headers: response_headers(script_hashes),
      rails_segment: segment(rails.current_stable),
      ecosystem_segments: Source.where.not(slug: "rails").order(:slug)
                                .filter_map { |s| [ s.slug, segment(s.current_stable) ] if s.current_stable }
    )
  end

  # What Rails sends with every response, so the files carry the same
  # security headers the app does.
  def response_headers(script_hashes)
    Rails.application.config.action_dispatch.default_headers
         .merge("Content-Security-Policy" => content_security_policy(script_hashes))
  end

  # The app's own policy, with the nonce swapped for the hashes of the
  # inline scripts actually seen in the pages (the importmap and its
  # module entry point), plus the build's style nonce.
  def content_security_policy(script_hashes)
    policy = Rails.application.config.content_security_policy.dup
    policy.script_src(*policy.directives["script-src"], *script_hashes.sort.map { |h| "'sha256-#{h}'" })
    policy.style_src(*policy.directives["style-src"], "'nonce-#{style_nonce}'")
    policy.build
  end

  # Turbo injects its progress bar's <style> on every page load, tagged
  # with the page's csp-nonce. A file can't carry a per-request nonce, so
  # every page carries this one, allowed for style-src only. Derived from
  # the asset manifest: stable across builds of the same code, new
  # whenever the assets (Turbo included) change.
  def style_nonce
    @style_nonce ||= Digest::SHA256.hexdigest(File.read(File.join(public_dir, "assets/.manifest.json")))[0, 32]
  end

  def rails
    @rails ||= Source.find_by!(slug: "rails")
  end

  def version_base(pv)
    pv.source == rails ? "/#{segment(pv)}" : "/#{pv.source.slug}/#{segment(pv)}"
  end

  def segment(pv)
    pv.channel == "edge" ? "edge" : "v#{pv.channel}"
  end

  class Tally
    attr_reader :files, :bytes, :failures, :script_hashes
    attr_accessor :elapsed

    def initialize(files: 0, bytes: 0, failures: [], script_hashes: [])
      @files = files
      @bytes = bytes
      @failures = failures
      @script_hashes = script_hashes.to_set
    end

    def wrote(bytesize)
      @files += 1
      @bytes += bytesize
    end

    def failed(page, status)
      @failures << "#{status} #{page.url}"
    end

    def merge!(other)
      @files += other.files
      @bytes += other.bytes
      @failures.concat(other.failures)
      @script_hashes.merge(other.script_hashes)
      self
    end

    def to_h
      { files:, bytes:, failures:, script_hashes: script_hashes.to_a }
    end

    def summary
      "#{files.to_fs(:delimited)} files, #{bytes.to_fs(:human_size)}" +
        (failures.any? ? ", #{failures.size} failed" : "")
    end
  end
end
