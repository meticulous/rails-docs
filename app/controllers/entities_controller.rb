class EntitiesController < ApplicationController
  before_action :load_available_versions

  def show
    @package_version = current_source.package_versions.find_by!(channel: channel_from_param)
    @identity = resolve_entity!
    @entity_version = @identity.entity_versions.find_by(package_version: @package_version)

    if @entity_version
      @presenter = build_presenter
      render template_for(@identity)
    else
      render "entities/missing", status: :not_found
    end
  end

  private

  def load_available_versions
    @available_versions = PackageVersion.where.not(ingested_at: nil).order(ord: :desc)
  end

  def channel_from_param
    params[:version] == "edge" ? "edge" : params[:version].sub(/\Av/, "")
  end

  def resolve_entity!
    parts = params[:path].split("/")
    raise ActiveRecord::RecordNotFound if parts.empty?

    identity = resolve_class_or_module(parts) ||
               resolve_method(parts) ||
               resolve_attribute(parts) ||
               resolve_constant(parts)
    identity || raise(ActiveRecord::RecordNotFound, "No entity for path: #{params[:path].inspect}")
  end

  # Walk the URL segments down the namespace tree, matching each one
  # against `name.underscore` rather than `name == segment.camelize`.
  # That way acronym-y names like ActiveRecord::ConnectionAdapters::
  # PostgreSQLAdapter resolve from /active_record/connection_adapters/
  # postgre_sql_adapter without needing an Inflector#acronym table —
  # whatever url_path produces, this reverses.
  def resolve_class_or_module(parts)
    walk_namespace(parts)
  end

  def resolve_method(parts)
    return nil if parts.size < 2
    parent = walk_namespace(parts[0..-2])
    return nil unless parent
    last = parts.last
    scope, slug = last.end_with?(".class") ? [ "singleton", last.sub(/\.class\z/, "") ] : [ "instance", last ]
    decoded = MethodSlug.decode(slug)

    # URL slugs are always underscored (EntityIdentity#url_path calls
    # .underscore on each FQN segment), so a method named POST round-
    # trips through the URL as "post". Match either the literal decoded
    # slug or its underscored form so all-caps names resolve.
    source.entity_identities
          .where(kind: "method", scope: scope, parent_fqn: parent.fqn)
          .find { |id| id.name == decoded || id.name.underscore == decoded }
  end

  def resolve_attribute(parts)
    return nil if parts.size < 2
    parent = walk_namespace(parts[0..-2])
    return nil unless parent
    source.entity_identities
          .where(kind: "attribute", scope: "instance", parent_fqn: parent.fqn)
          .find { |id| id.name == parts.last || id.name.underscore == parts.last }
  end

  # Constants are typically ALL_CAPS — the URL slug lowercases them
  # ("INTERNAL" → "internal"). Match by underscored name so the slug
  # round-trips; ~1,150 of Rails' ~12k constants would otherwise 404.
  def resolve_constant(parts)
    return nil if parts.size < 2
    parent = walk_namespace(parts[0..-2])
    return nil unless parent
    source.entity_identities
          .where(kind: "constant", parent_fqn: parent.fqn)
          .find { |id| id.name == parts.last || id.name.underscore == parts.last }
  end

  # Resolve a class/module identity from a list of URL segments. Tries
  # the well-behaved fast path first (camelize each segment and look up
  # the resulting FQN directly — one indexed query) before falling back
  # to a hierarchical walk that compares each segment against
  # `name.underscore` so acronymy names like PostgreSQLAdapter resolve
  # without an inflections table.
  def walk_namespace(segments)
    return nil if segments.empty?

    fast = source.entity_identities
                 .where(kind: %w[class module], fqn: segments.map(&:camelize).join("::"))
                 .first
    return fast if fast

    parent_fqn = nil
    current = nil
    segments.each do |segment|
      current = source.entity_identities
                      .where(kind: %w[class module], parent_fqn: parent_fqn)
                      .find { |id| id.name.underscore == segment }
      return nil unless current
      parent_fqn = current.fqn
    end
    current
  end

  def build_presenter
    case @identity.kind
    when "class", "module" then ClassPresenter.new(@entity_version)
    when "method" then MethodPresenter.new(@entity_version)
    else ClassPresenter.new(@entity_version) # constants/attributes reuse the class layout for now
    end
  end

  def template_for(identity)
    case identity.kind
    when "method" then "entities/method"
    else "entities/class"
    end
  end

  def source
    current_source
  end
end
