class MethodPresenter
  attr_reader :entity_version, :identity, :package_version

  def initialize(entity_version)
    @entity_version = entity_version
    @identity = entity_version.entity_identity
    @package_version = entity_version.package_version
  end

  delegate :fqn, :name, :kind, :scope, to: :identity
  delegate :doc_html, :doc_markdown, :doc_summary, :signature_text, :call_seq,
           :source_path, :source_line_start, :source_line_end, :source_code,
           :visibility, :deprecated, :deprecation_note,
           to: :entity_version

  def title
    "#{display_signature} — #{identity.parent_fqn} — Ruby on Rails #{package_version.channel}"
  end

  def display_signature
    base = signature_text.present? ? "#{name}#{signature_text}" : name
    "#{scope_prefix}#{base}"
  end

  def scope_prefix
    scope == "singleton" ? "self." : ""
  end

  def parent_identity
    return nil unless identity.parent_fqn
    @parent_identity ||= identity.source.entity_identities
                                 .where(kind: %w[class module])
                                 .find_by(fqn: identity.parent_fqn)
  end

  def method_params
    entity_version.method_params.order(:position)
  end

  def method_version
    entity_version.method_version
  end

  def aliased
    method_version&.aliased
  end
end
