class ClassPresenter
  attr_reader :entity_version, :identity, :package_version

  def initialize(entity_version)
    @entity_version = entity_version
    @identity = entity_version.entity_identity
    @package_version = entity_version.package_version
  end

  delegate :fqn, :name, :kind, to: :identity
  delegate :doc_html, :doc_markdown, :doc_summary, :source_path, :source_line_start, to: :entity_version

  def title
    "#{fqn} — Ruby on Rails #{package_version.channel}"
  end

  def own_methods
    @own_methods ||= methods_for([identity.fqn]).order(:scope, :name).to_a
  end

  def inherited_methods_grouped
    return @inherited_methods_grouped if defined?(@inherited_methods_grouped)

    ancestor_fqns = ordered_ancestor_fqns
    return @inherited_methods_grouped = [] if ancestor_fqns.empty?

    grouped = methods_for(ancestor_fqns).group_by(&:parent_fqn)
    @inherited_methods_grouped = ancestor_fqns.filter_map { |fqn|
      rows = grouped[fqn]
      next unless rows
      [fqn, rows.sort_by { |r| [r.scope.to_s, r.name] }]
    }
  end

  def superclass_identity
    return @superclass_identity if defined?(@superclass_identity)
    @superclass_identity = entity_version.class_version&.superclass_identity
  end

  def included_modules
    @included_modules ||= edges_by_relation("include")
  end

  def extended_modules
    @extended_modules ||= edges_by_relation("extend")
  end

  def prepended_modules
    @prepended_modules ||= edges_by_relation("prepend")
  end

  def constants
    @constants ||= methods_for([identity.fqn], kind: "constant").order(:name).to_a
  end

  def attributes
    @attributes ||= methods_for([identity.fqn], kind: "attribute").order(:name).to_a
  end

  private

  def methods_for(parent_fqns, kind: "method")
    identity.source.entity_identities
            .where(parent_fqn: parent_fqns, kind: kind)
            .joins(:entity_versions)
            .where(entity_versions: { package_version_id: package_version.id })
            .distinct
  end

  def ordered_ancestor_fqns
    InheritanceClosure
      .joins("JOIN entity_identities ON entity_identities.id = inheritance_closures.ancestor_identity_id")
      .where(descendant_identity_id: identity.id, package_version_id: package_version.id)
      .order(:depth, "entity_identities.fqn")
      .pluck("entity_identities.fqn")
  end

  def edges_by_relation(relation)
    InheritanceEdge
      .where(child_identity_id: identity.id, package_version_id: package_version.id, relation: relation)
      .includes(:ancestor_identity)
      .order(Arel.sql("COALESCE(position, 0)"))
      .map(&:ancestor_identity)
  end
end
