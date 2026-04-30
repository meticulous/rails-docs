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
    return content_tag(:code, text, class: "ghost-method") if ghost_method?(identity)
    link_to text, entity_path_for(identity, package_version)
  end

  def ghost_method?(identity)
    identity.kind == "method" && identity.name.to_s.include?("*")
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
end
