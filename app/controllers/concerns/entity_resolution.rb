# Turns an entity URL (/v8.1.3/active_record/persistence/save.class)
# back into the PackageVersion and EntityIdentity it names, for the
# controllers that serve entity URLs.
module EntityResolution
  private

  def requested_package_version
    current_source.package_versions.find_by!(channel: params[:version].delete_prefix("v"))
  end

  # Prefers an identity present in package_version: one path can name
  # different identities over the years (set_cookie was a method, then an
  # attribute; ERB has both class and module identities), and the version
  # asked for decides which. Falls back to any version, so a path that
  # exists elsewhere still resolves — for the "not in this version" page.
  def resolve_entity!(path, package_version)
    parts = path.split("/")
    raise ActiveRecord::RecordNotFound if parts.empty?

    in_version = current_source.entity_identities
                               .joins(:entity_versions)
                               .where(entity_versions: { package_version_id: package_version.id })

    [ in_version, current_source.entity_identities ].each do |identities|
      identity = walk_namespace(identities, parts) || resolve_member(identities, parts)
      return identity if identity
    end

    raise ActiveRecord::RecordNotFound, "No entity for path: #{path.inspect}"
  end

  # The last segment names a method, attribute, or constant of the
  # class/module the rest of the path walks to.
  def resolve_member(identities, parts)
    return if parts.size < 2
    parent = walk_namespace(identities, parts[0..-2]) or return

    members = identities.where(parent_fqn: parent.fqn)
    resolve_method(members, parts.last) ||
      resolve_attribute(members, parts.last) ||
      resolve_constant(members, parts.last)
  end

  # A slug that is itself a method name wins: QueryMethods#and is "and",
  # the same slug the & operator encodes to. Otherwise match the decoded
  # slug or its underscored form — URL slugs are always underscored
  # (EntityIdentity#url_path calls .underscore on each FQN segment), so a
  # method named POST round-trips through the URL as "post".
  def resolve_method(members, slug)
    scope, slug = slug.end_with?(".class") ? [ "singleton", slug.delete_suffix(".class") ] : [ "instance", slug ]
    decoded = MethodSlug.decode(slug)
    methods = members.where(kind: "method", scope: scope).to_a
    methods.find { |id| id.name == slug } ||
      methods.find { |id| id.name == decoded || id.name.underscore == decoded }
  end

  def resolve_attribute(members, slug)
    decoded = MethodSlug.decode(slug)
    members.where(kind: "attribute", scope: "instance")
           .find { |id| [ id.name, id.name.underscore ].include?(slug) || id.name == decoded }
  end

  # Constants are typically ALL_CAPS — the URL slug lowercases them
  # ("INTERNAL" → "internal"). Match by underscored name so the slug
  # round-trips; ~1,150 of Rails' ~12k constants would otherwise 404.
  def resolve_constant(members, slug)
    members.where(kind: "constant").find { |id| id.name == slug || id.name.underscore == slug }
  end

  # Resolve a class/module identity from a list of URL segments. Tries
  # the well-behaved fast path first (camelize each segment and look up
  # the resulting FQN directly — one indexed query) before falling back
  # to a hierarchical walk that compares each segment against
  # `name.underscore`, so acronym-y names like ActiveRecord::
  # ConnectionAdapters::PostgreSQLAdapter resolve from .../postgre_sql_adapter
  # without an inflections table — whatever url_path produces, this
  # reverses.
  def walk_namespace(identities, segments)
    return nil if segments.empty?

    fast = identities.where(kind: %w[class module], fqn: segments.map(&:camelize).join("::")).first
    return fast if fast

    parent_fqn = nil
    current = nil
    segments.each do |segment|
      current = identities.where(kind: %w[class module], parent_fqn: parent_fqn)
                          .find { |id| id.name.underscore == segment }
      return nil unless current
      parent_fqn = current.fqn
    end
    current
  end
end
