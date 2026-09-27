require "test_helper"

class StaticSiteTest < ActiveSupport::TestCase
  setup do
    @out = Dir.mktmpdir("static_site_test")
    package_versions(:v8_1_3).update!(ingested_at: Time.current)
    @tally = StaticSite.new(@out, host: "api.rubyonrails.org", upstream: "http://rails-docs.web", resolver: "127.0.0.11").build
  end

  teardown do
    FileUtils.rm_rf(@out)
  end

  test "exports every entity as HTML, markdown, and JSON" do
    assert_empty @tally.failures

    %w[active_record/persistence active_record/persistence/save foo/bar].each do |path|
      %w[html md json].each { |ext| assert_exported "v8.1.3/#{path}.#{ext}" }
    end
    assert_includes exported("v8.1.3/active_record/persistence/save.html"), "Saves the record."
    assert_equal "ActiveRecord::Persistence#save",
                 JSON.parse(exported("v8.1.3/active_record/persistence/save.json"))["fqn"]
    assert_exported "v8.1.3/og/active_record/persistence/save.svg"
  end

  test "exports site-wide pages, per-version pages, the nav frames, and assets" do
    %w[
      index.html ecosystem.html llms.txt sitemap.xml 404.html
      v8.1.3/index.html v8.1.3/sitemap.xml
      _nav/rails/v8.1.3.html _nav/rails/v8.1.3/ecosystem.html
      feeds/sources/rails.atom assets/.manifest.json
    ].each { |file| assert_exported file }
  end

  test "swaps per-request tokens for build-wide ones so builds are reproducible" do
    html = exported("v8.1.3/active_record/persistence/save.html")
    nonce = html[/<meta name="csp-nonce" content="(\w+)"/, 1]

    assert_no_match(/ nonce=|csrf-token/, html)
    assert_equal nonce, exported("index.html")[/<meta name="csp-nonce" content="(\w+)"/, 1]
    assert_includes File.read(File.join(@out, "nginx.conf")), "style-src 'self' 'nonce-#{nonce}'"
  end

  test "nginx config allows the inline scripts by hash and redirects version-less paths" do
    conf = File.read(File.join(@out, "nginx.conf"))

    assert_match(/script-src 'self' 'sha256-[^']+'/, conf)
    assert_includes conf, "/v8.1.3/$1 redirect"
    assert_includes conf, "set $rails http://rails-docs.web;"
    assert_includes conf, %(add_header X-Frame-Options "SAMEORIGIN" always;)
  end

  test "a hostname upstream needs a resolver" do
    assert_raises(ArgumentError) { StaticSite.new(@out, host: "localhost", upstream: "http://rails-docs.web") }
    assert_nothing_raised { StaticSite.new(@out, host: "localhost", upstream: "http://10.0.0.5:3000") }
  end

  private

  def assert_exported(file)
    assert File.exist?(File.join(@out, "public", file)), "expected #{file} to be exported"
  end

  def exported(file)
    File.read(File.join(@out, "public", file))
  end
end
