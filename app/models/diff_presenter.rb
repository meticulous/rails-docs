require "diff/lcs"

# Compares two entity_versions of the same entity_identity. The "from" or
# "to" side may be nil — that's how we represent "added in this version" or
# "removed in this version".
class DiffPresenter
  attr_reader :identity, :from_version, :to_version, :from, :to

  def initialize(identity:, from_version:, to_version:)
    @identity = identity
    @from_version = from_version
    @to_version = to_version
    @from = identity.entity_versions.find_by(package_version: from_version)
    @to = identity.entity_versions.find_by(package_version: to_version)
  end

  def title
    "#{identity.fqn} — #{version_label(@from_version)} → #{version_label(@to_version)}"
  end

  def added?
    @from.nil? && @to.present?
  end

  def removed?
    @from.present? && @to.nil?
  end

  def both_present?
    @from.present? && @to.present?
  end

  def doc_diff
    @doc_diff ||= line_diff(@from&.doc_markdown, @to&.doc_markdown)
  end

  def signature_diff
    @signature_diff ||= line_diff(@from&.signature_text, @to&.signature_text)
  end

  def doc_changed?
    return false unless both_present?
    @from.doc_markdown.to_s != @to.doc_markdown.to_s
  end

  def signature_changed?
    return false unless both_present?
    @from.signature_text.to_s != @to.signature_text.to_s
  end

  # Returns an array of [tag, from_line, to_line] from Diff::LCS::sdiff.
  # Tag is "=" (unchanged), "+" (added), "-" (removed), "!" (changed).
  def line_diff(from_text, to_text)
    from_lines = (from_text || "").lines
    to_lines = (to_text || "").lines
    Diff::LCS.sdiff(from_lines, to_lines).map do |change|
      [change.action, change.old_element&.chomp, change.new_element&.chomp]
    end
  end

  private

  def version_label(pv)
    pv.channel == "edge" ? "edge" : "v#{pv.channel}"
  end
end
