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

  # `{{source-slug:Some::Fqn}}` or `{{source-slug:Some::Fqn|Custom Label}}` —
  # both `turbo-rails` (canonical slug) and `turbo` (alias) accepted.
  CROSS_SOURCE_TOKEN_REGEX = /\{\{\s*([\w-]+):([A-Z][\w:#.]+?)(?:\|([^}]+))?\s*\}\}/.freeze

  CROSS_SOURCE_ALIASES = {
    "turbo" => "turbo-rails",
    "stimulus" => "stimulus-rails",
    "importmap" => "importmap-rails"
  }.freeze

  # Sanitize-then-link. Apply token expansion before sanitize so the
  # produced anchor tags get through the allow-list.
  def sanitize_doc_html(html)
    return nil if html.blank?
    expanded = html.include?("{{") ? expand_cross_source_tokens(expand_guide_tokens(html)) : html
    sanitize expanded, tags: DOC_HTML_TAGS, attributes: DOC_HTML_ATTRIBUTES
  end

  # Expand `{{guide:slug}}`, `{{guide:slug#anchor}}`, and
  # `{{guide:slug#anchor|Custom label}}` tokens to links pointing at
  # guides.rubyonrails.org. Authors place these in RDoc comments to cross-
  # reference the prose docs without hard-coding the URL.
  def expand_guide_tokens(html)
    return html unless html.include?("{{")
    html.gsub(GUIDE_TOKEN_REGEX) do
      slug, anchor, label = Regexp.last_match(1), Regexp.last_match(2), Regexp.last_match(3)
      href = "https://guides.rubyonrails.org/#{slug}.html"
      href += "##{anchor}" if anchor
      text = label || default_guide_label(slug, anchor)
      %(<a href="#{ERB::Util.h(href)}" rel="external">#{ERB::Util.h(text)}</a>)
    end
  end

  # Expand cross-source FQN references — `{{turbo:Turbo::StreamsChannel}}`
  # links to that entity in turbo-rails' current_stable. Skipped (left
  # as the literal token) when the source isn't ingested or has no
  # stable version yet.
  def expand_cross_source_tokens(html)
    return html unless html.include?("{{")
    html.gsub(CROSS_SOURCE_TOKEN_REGEX) do
      slug_or_alias, fqn, label = Regexp.last_match(1), Regexp.last_match(2), Regexp.last_match(3)
      source_slug = CROSS_SOURCE_ALIASES.fetch(slug_or_alias, slug_or_alias)
      pv = cross_source_current_stable[source_slug]
      next Regexp.last_match(0) unless pv

      href = "/#{source_slug}/v#{pv.channel}/#{EntityIdentity.fqn_to_url_path(fqn.tr('#.', '/'))}"
      %(<a href="#{ERB::Util.h(href)}"><code>#{ERB::Util.h(label || fqn)}</code></a>)
    end
  end

  private

  def default_guide_label(slug, anchor)
    base = slug.tr("_-", "  ").gsub("/", " / ").split.map(&:capitalize).join(" ")
    anchor ? "#{base}: #{anchor.tr("-", " ").capitalize}" : base
  end

  # Per-render cache of {source_slug => current_stable PackageVersion}.
  def cross_source_current_stable
    @cross_source_current_stable ||= PackageVersion
      .current_stable_for_each_source
      .index_by { |pv| pv.source.slug }
  end
end
