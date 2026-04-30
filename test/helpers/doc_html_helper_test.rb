require "test_helper"

class DocHtmlHelperTest < ActionView::TestCase
  test "passes through plain HTML untouched (after allow-list sanitize)" do
    html = "<p>Hello <code>world</code></p>"
    assert_equal html, sanitize_doc_html(html)
  end

  test "expands a bare {{guide:slug}} token to a guides.rubyonrails.org link" do
    html = "<p>See {{guide:active_record_querying}}.</p>"
    result = sanitize_doc_html(html)
    assert_match %r{<a href="https://guides.rubyonrails.org/active_record_querying.html"[^>]*>Active Record Querying</a>}, result
  end

  test "expands {{guide:slug#anchor}} with an anchor and capitalized label" do
    html = "<p>{{guide:active_record_querying#scope}}</p>"
    result = sanitize_doc_html(html)
    assert_match %r{href="https://guides.rubyonrails.org/active_record_querying.html#scope"}, result
    assert_match %r{Active Record Querying: Scope}, result
  end

  test "honors a custom label after the pipe" do
    html = "<p>{{guide:active_record_querying#scope|Scope chains}}</p>"
    result = sanitize_doc_html(html)
    assert_match %r{>Scope chains</a>}, result
  end

  test "leaves non-token braces alone" do
    html = "<p>{{ not a guide token }}</p>"
    result = sanitize_doc_html(html)
    assert_includes result, "{{ not a guide token }}"
  end

  test "strips disallowed tags" do
    html = '<p>safe</p><script>alert(1)</script>'
    result = sanitize_doc_html(html)
    assert_not_includes result, "<script>"
  end

  test "expands {{turbo:Turbo::StreamsChannel}} to a turbo-rails link" do
    src = Source.find_or_create_by!(slug: "turbo-rails", display_name: "Turbo Rails", github_repo: "hotwired/turbo-rails")
    pv = src.package_versions.find_or_create_by!(channel: "2.0.16") do |p|
      p.git_ref = "v2.0.16"; p.git_sha = "abc"; p.ord = 2000016; p.ingest_status = "ok"; p.ingested_at = Time.current
    end
    pv.update!(ingested_at: Time.current, ingest_status: "ok") if pv.ingested_at.nil?

    html = "<p>See {{turbo:Turbo::StreamsChannel}}.</p>"
    result = sanitize_doc_html(html)
    assert_match %r{href="/turbo-rails/v2.0.16/turbo/streams_channel"}, result
    assert_match %r{<code>Turbo::StreamsChannel</code>}, result
  end

  test "leaves cross-source token alone when source isn't ingested" do
    html = "<p>{{nonsense:Some::Class}}</p>"
    assert_includes sanitize_doc_html(html), "{{nonsense:Some::Class}}"
  end

  test "blank input returns nil" do
    assert_nil sanitize_doc_html(nil)
    assert_nil sanitize_doc_html("")
    assert_nil sanitize_doc_html("   ")
  end
end
