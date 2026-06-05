# Server-side syntax highlighting via Rouge (the highlighter rails/guides
# uses). Rouge's HTML formatter emits CSS-class spans — no inline styles —
# so it stays clean against our CSP. The theme lives in application.css
# under `.highlight`, copied from the guides palette.
module SyntaxHighlightHelper
  FORMATTER = Rouge::Formatters::HTML.new

  # Highlight a block of code. Returns a safe `<pre class="highlight">…`.
  # Defaults to the Ruby lexer (almost all code on the site is Ruby);
  # pass a different lexer name for shell/erb/etc.
  def highlight_code(source, lexer: "ruby")
    return "" if source.blank?
    lexer_class = Rouge::Lexer.find(lexer.to_s) || Rouge::Lexers::PlainText
    inner = FORMATTER.format(lexer_class.new.lex(source.to_s))
    tag.pre(tag.code(inner.html_safe), class: "highlight") # rubocop:disable Rails/OutputSafety
  end

  # Re-highlight `<pre><code>` blocks already present in sanitized doc HTML.
  # RDoc/doc comments embed code examples as plain <pre><code>…</code></pre>;
  # this swaps in Rouge spans. Skipped entirely when there's no <pre>.
  def highlight_doc_code(html)
    return html if html.blank? || !html.include?("<pre")
    doc = Nokogiri::HTML.fragment(html)
    doc.css("pre").each do |pre|
      code = pre.at_css("code") || pre
      highlighted = FORMATTER.format(Rouge::Lexers::Ruby.new.lex(code.text))
      pre.replace(%(<pre class="highlight"><code>#{highlighted}</code></pre>))
    end
    doc.to_html.html_safe # rubocop:disable Rails/OutputSafety
  end
end
