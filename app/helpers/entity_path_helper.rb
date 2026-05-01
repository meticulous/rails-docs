module EntityPathHelper
  # Renders a link to an entity_identity, defaulting the visible label to
  # the entity's FQN. Pass label: to override.
  #
  # Ghost methods — names like `*_changed?`, `*_was`, `*=` that RDoc uses
  # to document a family of dynamically-generated methods — don't have a
  # canonical URL (and their `?`/`!`/`*` characters bust the route
  # constraint anyway). Render them as plain code instead of a link.
  def entity_link(identity, package_version, label: nil)
    text = label || identity.fqn
    return content_tag(:code, text, class: "ghost-method", title: identity.fqn) if ghost_method?(identity)
    link_to text, entity_path_for(identity, package_version), title: identity.fqn
  end

  # `*` and `**` on their own are real Ruby operator methods (multiplication,
  # exponentiation/double-splat). Treat the wildcard as a ghost marker only
  # when it's mixed with other characters.
  def ghost_method?(identity)
    return false unless identity.kind == "method"
    name = identity.name.to_s
    name.include?("*") && name != "*" && name != "**"
  end

  # Builds a URL path for an entity_identity within a given package_version.
  # Class/module/constant/attribute return the namespace path; methods
  # append the slug-encoded method name with a `.class` suffix for singletons.
  def entity_path_for(identity, package_version)
    entity_path(version: version_url_segment(package_version), path: entity_url_path(identity))
  end

  def entity_url_path(identity)
    case identity.kind
    when "class", "module", "constant"
      identity.url_path
    when "method"
      slug = MethodSlug.encode(identity.name)
      slug = "#{slug}.class" if identity.scope == "singleton"
      "#{EntityIdentity.fqn_to_url_path(identity.parent_fqn)}/#{slug}"
    when "attribute"
      "#{EntityIdentity.fqn_to_url_path(identity.parent_fqn)}/#{identity.name}"
    else
      identity.url_path
    end
  end

  # Path-from-FQN for ad-hoc cases (inherited methods rendered from raw FQN
  # strings, breadcrumb intermediate segments). Delegates to EntityIdentity's
  # canonical impl.
  def fqn_to_path(fqn)
    EntityIdentity.fqn_to_url_path(fqn)
  end

  def breadcrumb_segments(fqn)
    EntityIdentity.breadcrumb_segments_for(fqn)
  end

  # Builds breadcrumbs for a specific entity. Each ancestor namespace
  # becomes its own [label, url] crumb (so /v8.1.2/action_text/encryption/
  # decrypt shows ActionText > Encryption > #decrypt with each segment
  # clickable except the last). For methods and attributes the leaf
  # uses the proper slug-encoded URL via entity_url_path so operator
  # methods like #[] (slug "-bracket") still resolve.
  def breadcrumbs_for(identity, package_version)
    namespace_fqn, leaf_label =
      case identity.kind
      when "method"
        prefix = identity.scope == "singleton" ? "." : "#"
        [ identity.parent_fqn, "#{prefix}#{identity.name}" ]
      when "attribute"
        [ identity.parent_fqn, "##{identity.name}" ]
      else
        # class, module, constant — the FQN itself is the namespace path,
        # the last `::` segment is the leaf.
        parts = identity.fqn.split("::")
        [ parts[0..-2].join("::").presence, parts.last ]
      end

    segments = []
    if namespace_fqn.present?
      parts = namespace_fqn.split("::")
      parts.each_with_index do |part, i|
        segments << [ part, entity_path(version: version_url_segment(package_version),
                                         path: parts[0..i].map(&:underscore).join("/")), false ]
      end
    end
    segments << [ leaf_label, entity_path_for(identity, package_version), true ]
    segments
  end
end
