module EntityPathHelper
  # Renders a link to an entity_identity, defaulting the visible label to
  # the entity's FQN. Pass label: to override.
  def entity_link(identity, package_version, label: nil)
    link_to label || identity.fqn, entity_path_for(identity, package_version)
  end

  # Builds a URL path for an entity_identity within a given package_version.
  # Class/module/constant/attribute return the namespace path; methods
  # append the slug-encoded method name with a `.class` suffix for singletons.
  def entity_path_for(identity, package_version)
    entity_path(version: version_url_segment(package_version), path: entity_url_path(identity))
  end

  def entity_url_path(identity)
    case identity.kind
    when "class", "module"
      fqn_to_path(identity.fqn)
    when "constant"
      fqn_to_path(identity.fqn)
    when "method"
      parent_path = fqn_to_path(identity.parent_fqn)
      slug = MethodSlug.encode(identity.name)
      slug = "#{slug}.class" if identity.scope == "singleton"
      "#{parent_path}/#{slug}"
    when "attribute"
      "#{fqn_to_path(identity.parent_fqn)}/#{identity.name}"
    else
      fqn_to_path(identity.fqn)
    end
  end

  # ActiveRecord::Persistence::ClassMethods -> active_record/persistence/class_methods
  def fqn_to_path(fqn)
    fqn.to_s.split("::").map(&:underscore).join("/")
  end

  def github_source_url(entity_version)
    return nil unless entity_version.source_path.present? && entity_version.source_line_start.present?
    repo = entity_version.entity_identity.source.github_repo
    ref = entity_version.package_version.git_ref
    line = "#L#{entity_version.source_line_start}"
    line += "-L#{entity_version.source_line_end}" if entity_version.source_line_end.present?
    "https://github.com/#{repo}/blob/#{ref}/#{entity_version.source_path}#{line}"
  end

  def github_edit_url(entity_version)
    return nil unless entity_version.source_path.present?
    repo = entity_version.entity_identity.source.github_repo
    ref = entity_version.package_version.git_ref
    "https://github.com/#{repo}/edit/#{ref}/#{entity_version.source_path}"
  end

  # FQN -> array of [name_part, partial_path] for breadcrumb rendering.
  # ActiveRecord::Persistence::ClassMethods becomes
  # [["ActiveRecord", "active_record"], ["Persistence", "active_record/persistence"], ...]
  def breadcrumb_segments(fqn)
    parts = fqn.to_s.split("::")
    parts.each_with_index.map do |part, i|
      [part, parts[0..i].map(&:underscore).join("/")]
    end
  end
end
