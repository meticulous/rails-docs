# Sanitizes the doc_html column. RDoc's HTML output is generally trustworthy,
# but we lock the tag/attribute set here so a future ingester (or a
# hypothetical compromised dump) can't smuggle <script>.
module DocHtmlHelper
  DOC_HTML_TAGS = %w[
    p code pre h1 h2 h3 h4 h5 h6 ul ol li a strong em b i
    blockquote table thead tbody tr td th hr br span div dl dt dd img
    sub sup
  ].freeze

  DOC_HTML_ATTRIBUTES = %w[href id class title alt src lang].freeze

  def sanitize_doc_html(html)
    sanitize html, tags: DOC_HTML_TAGS, attributes: DOC_HTML_ATTRIBUTES
  end
end
