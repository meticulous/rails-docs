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

  test "blank input returns nil" do
    assert_nil sanitize_doc_html(nil)
    assert_nil sanitize_doc_html("")
    assert_nil sanitize_doc_html("   ")
  end
end
