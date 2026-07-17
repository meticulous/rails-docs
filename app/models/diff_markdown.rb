# Renders a DiffPresenter as a Markdown document — the machine-readable
# twin of the diff page, served when the diff URL's other_version carries
# a `.md` suffix (or the request accepts text/markdown). Sections mirror
# the HTML page: signature, documentation, and source, each as a fenced
# diff block.
class DiffMarkdown
  def initialize(diff)
    @diff = diff
  end

  def to_s
    [ "# #{@diff.title}", *body ].join("\n\n") + "\n"
  end

  private

  def body
    return [ "Added in this version — not present in the base version." ] if @diff.added?
    return [ "Removed in this version — present only in the base version." ] if @diff.removed?

    sections = []
    sections << section("Signature", @diff.signature_diff) if @diff.signature_changed?
    sections << section("Documentation", @diff.doc_diff) if @diff.doc_changed?
    sections << section("Source", @diff.source_diff) if @diff.source_changed?
    sections.empty? ? [ "Signature, documentation, and source are identical." ] : sections
  end

  def section(title, lines)
    "## #{title}\n\n#{fence(lines)}"
  end

  # Same line semantics as diffs/_lines.html.erb: "=" unchanged,
  # "-" removed, "+" added, "!" changed (renders as a remove + an add).
  def fence(lines)
    rendered = lines.flat_map do |action, from_line, to_line|
      case action
      when "=" then [ "  #{from_line}" ]
      when "-" then [ "- #{from_line}" ]
      when "+" then [ "+ #{to_line}" ]
      when "!" then [ "- #{from_line}", "+ #{to_line}" ]
      end
    end
    "```diff\n#{rendered.join("\n")}\n```"
  end
end
