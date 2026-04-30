# Sanitizes the doc_html column and expands custom Rails-docs reference
# tokens. RDoc's HTML output is generally trustworthy, but we lock the
# tag/attribute set here so a future ingester (or a hypothetical compromised
# dump) can't smuggle <script>.
module DocHtmlHelper
  DOC_HTML_TAGS = %w[
    p code pre h1 h2 h3 h4 h5 h6 ul ol li a strong em b i
    blockquote table thead tbody tr td th hr br span div dl dt dd img
    sub sup
  ].freeze

  DOC_HTML_ATTRIBUTES = %w[href id class title alt src lang rel target].freeze

  GUIDE_TOKEN_REGEX = /\{\{\s*guide:([\w_\/-]+?)(?:#([\w-]+))?(?:\|([^}]+))?\s*\}\}/.freeze

  # Sanitize-then-link. Apply guide-token expansion before sanitize so the
  # produced anchor tags get through the allow-list.
  def sanitize_doc_html(html)
    return nil if html.blank?
    sanitize expand_guide_tokens(html), tags: DOC_HTML_TAGS, attributes: DOC_HTML_ATTRIBUTES
  end

  # Expand `{{guide:slug}}`, `{{guide:slug#anchor}}`, and
  # `{{guide:slug#anchor|Custom label}}` tokens to links pointing at
  # guides.rubyonrails.org. Authors place these in RDoc comments to cross-
  # reference the prose docs without hard-coding the URL.
  def expand_guide_tokens(html)
    html.gsub(GUIDE_TOKEN_REGEX) do
      slug, anchor, label = Regexp.last_match(1), Regexp.last_match(2), Regexp.last_match(3)
      href = "https://guides.rubyonrails.org/#{slug}.html"
      href += "##{anchor}" if anchor
      text = label || default_guide_label(slug, anchor)
      %(<a href="#{ERB::Util.h(href)}" rel="external">#{ERB::Util.h(text)}</a>)
    end
  end

  private

  def default_guide_label(slug, anchor)
    base = slug.tr("_-", "  ").gsub("/", " / ").split.map(&:capitalize).join(" ")
    anchor ? "#{base}: #{anchor.tr("-", " ").capitalize}" : base
  end
end
