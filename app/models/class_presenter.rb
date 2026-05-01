class ClassPresenter
  attr_reader :entity_version, :identity, :package_version

  def initialize(entity_version)
    @entity_version = entity_version
    @identity = entity_version.entity_identity
    @package_version = entity_version.package_version
  end

  delegate :fqn, :name, :kind, to: :identity
  delegate :doc_html, :doc_markdown, :doc_summary, :source_path, :source_line_start, to: :entity_version

  def available_versions
    @available_versions ||= identity.available_versions.distinct.order(:ord).to_a
  end

  def first_seen_version
    identity.first_seen_version
  end

  def last_seen_version
    identity.last_seen_version
  end

  def title
    "#{fqn} — Ruby on Rails #{package_version.channel}"
  end

  def own_methods
    @own_methods ||= methods_for([ identity.fqn ]).order(:scope, :name).to_a
  end

  def public_own_methods
    @public_own_methods ||= own_methods.reject { |m| private_method?(m) }
  end

  def private_own_methods
    @private_own_methods ||= own_methods.select { |m| private_method?(m) }
  end

  def inherited_methods_grouped
    return @inherited_methods_grouped if defined?(@inherited_methods_grouped)

    ancestor_fqns = ordered_ancestor_fqns
    return @inherited_methods_grouped = [] if ancestor_fqns.empty?

    # Inherited methods are an API affordance — privates of the ancestor
    # aren't visible through the inheritance chain (Ruby's "private"
    # blocks them at call time), so we filter them out of this list to
    # avoid implying otherwise.
    grouped = methods_for(ancestor_fqns).reject { |m| private_method?(m) }.group_by(&:parent_fqn)
    @inherited_methods_grouped = ancestor_fqns.filter_map { |fqn|
      rows = grouped[fqn]
      next unless rows
      [ fqn, rows.sort_by { |r| [ r.scope.to_s, r.name ] } ]
    }
  end

  # Returns true when this method identity is private in the current
  # package_version. Cached per-presenter so the public/private partition
  # of own_methods is one batched lookup rather than a per-row N+1.
  def private_method?(method_identity)
    private_method_ids.include?(method_identity.id)
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

  # Classes and modules nested directly under this one in the current
  # package_version. Drives the "Namespace" section on a module page —
  # critical for namespace-y modules like ActionText that are mostly a
  # container for child classes.
  def nested_classes_and_modules
    @nested_classes_and_modules ||= identity.source.entity_identities
      .where(parent_fqn: identity.fqn, kind: %w[class module])
      .joins(:entity_versions)
      .where(entity_versions: { package_version_id: package_version.id })
      .distinct
      .order(:kind, :name)
      .to_a
  end

  def constants
    @constants ||= methods_for([ identity.fqn ], kind: "constant").order(:name).to_a
  end

  def attributes
    @attributes ||= methods_for([ identity.fqn ], kind: "attribute").order(:name).to_a
  end

  # Classes / modules that include, extend, prepend, or inherit from this
  # one in the current package_version. Useful for modules like
  # ActiveRecord::Persistence ("included by ActiveRecord::Base, ...").
  def inheritors
    return @inheritors if defined?(@inheritors)

    edges = InheritanceEdge
      .where(ancestor_identity_id: identity.id, package_version_id: package_version.id)
      .includes(:child_identity)
      .order(:relation, "entity_identities.fqn")

    @inheritors = edges.group_by(&:relation).transform_values do |group|
      group.map(&:child_identity).uniq
    end
  end

  private

  def private_method_ids
    @private_method_ids ||= EntityVersion
      .where(package_version_id: package_version.id, visibility: "private")
      .joins(:entity_identity)
      .where(entity_identities: { kind: "method" })
      .pluck(:entity_identity_id)
      .to_set
  end

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
