namespace :export do
  desc <<~DESC
    Build the whole site as static files, plus an nginx config serving them.
      bin/rails export:site HOST=localhost        # → tmp/site/{public,nginx.conf}
      bin/rails export:site OUT=path/dir HOST=api.rubyonrails.org
      bin/rails export:site JOBS=4                # parallel workers
      bin/rails export:site VERSIONS=8.1.3,edge   # a partial site: only these channels
      bin/rails export:site UPSTREAM=http://rails-docs.web RESOLVER=127.0.0.11
                                                  # proxy diffs/search to Rails
    HOST (default api.rubyonrails.org) must be allowed by config.hosts —
    RAILS_ALLOWED_HOSTS in production; in development use HOST=localhost.
    Each build replaces OUT/public entirely.
  DESC
  task site: :environment do
    out_dir = ENV.fetch("OUT", Rails.root.join("tmp/site").to_s)
    site = StaticSite.new(
      out_dir,
      host: ENV.fetch("HOST", "api.rubyonrails.org"),
      upstream: ENV["UPSTREAM"],
      resolver: ENV["RESOLVER"],
      jobs: ENV.fetch("JOBS", 1).to_i,
      channels: ENV["VERSIONS"]&.split(",")
    )
    $stdout.sync = true # progress lines come from forked workers
    tally = site.build { |pv, t| puts "  #{pv.source.slug} #{pv.channel}: #{t.summary}" }

    puts "Built #{tally.summary} in #{ActiveSupport::Duration.build(tally.elapsed.round).inspect} → #{out_dir}"
    puts "#{tally.failures.size} pages failed; see #{out_dir}/failures.txt" if tally.failures.any?
  end

  desc <<~DESC
    Build a Dash docset from a static export.
      bin/rails export:dash VERSION=8.1.2 [OUT=path/dir]
    Requires `bin/rails export:site` to have been run first into the same OUT.
  DESC
  task dash: :environment do
    requested = ENV["VERSION"] or abort "VERSION=8.1.2 required"
    out_dir = ENV.fetch("OUT", Rails.root.join("tmp/site").to_s)
    package_version = PackageVersion.find_by!(channel: requested)
    DashExport.new(package_version: package_version, static_dir: File.join(out_dir, "public"), out_dir: out_dir).run
  end
end
