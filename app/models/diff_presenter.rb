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

  # Versions in which this entity exists, oldest first — the option list for
  # the base/compare pickers in the diff header.
  def available_versions
    @available_versions ||= identity.available_versions.distinct.order(:ord).to_a
  end

  # package_version_ids whose content differs from the base (from) version.
  # Drives the "changed"/"same" tags on the compare picker so the reader can
  # see which versions actually differ from the one on the left.
  def changed_version_ids
    @changed_version_ids ||= identity.changed_version_ids(relative_to: @from_version)
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

  def source_diff
    @source_diff ||= line_diff(comparable_source(@from), comparable_source(@to))
  end

  def doc_changed?
    return false unless both_present?
    @from.doc_markdown.to_s != @to.doc_markdown.to_s
  end

  def signature_changed?
    return false unless both_present?
    @from.signature_text.to_s != @to.signature_text.to_s
  end

  def source_changed?
    return false unless both_present?
    comparable_source(@from) != comparable_source(@to)
  end

  # Returns an array of [tag, from_line, to_line] from Diff::LCS::sdiff.
  # Tag is "=" (unchanged), "+" (added), "-" (removed), "!" (changed).
  def line_diff(from_text, to_text)
    from_lines = (from_text || "").lines
    to_lines = (to_text || "").lines
    Diff::LCS.sdiff(from_lines, to_lines).map do |change|
      [ change.action, change.old_element&.chomp, change.new_element&.chomp ]
    end
  end

  private

  # RDoc prefixes source_code with "# File path, line N" — line numbers
  # drift with every release, so comparing (or diffing) that header would
  # mark byte-identical implementations as changed. Strip it here and in
  # EntityIdentity#content_digest_by_version, which must stay in
  # lockstep: "changed" means this page will show a real difference.
  def comparable_source(entity_version)
    entity_version&.source_code.to_s.sub(/\A# File .*\n?/, "")
  end

  def version_label(pv)
    pv.channel == "edge" ? "edge" : "v#{pv.channel}"
  end
end
