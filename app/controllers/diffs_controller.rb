class DiffsController < ApplicationController
  def show
    @from_version = current_source.package_versions.find_by!(channel: channel(params[:version]))
    @to_version = current_source.package_versions.find_by!(channel: channel(params[:other_version]))
    @identity = resolve_entity!(params[:entity_path])
    @diff = DiffPresenter.new(
      identity: @identity,
      from_version: @from_version,
      to_version: @to_version
    )
  end

  private

  def channel(segment)
    segment == "edge" ? "edge" : segment.sub(/\Av/, "")
  end

  # Mirrors EntitiesController's resolution but with the entity_path as an
  # explicit string argument. Could be lifted into a concern shared with
  # EntitiesController; deferring until a third caller appears.
  def resolve_entity!(entity_path)
    parts = entity_path.to_s.split("/")
    raise ActiveRecord::RecordNotFound if parts.empty?

    identity = resolve_class_or_module(parts) ||
               resolve_method(parts) ||
               resolve_attribute(parts) ||
               resolve_constant(parts)
    identity || raise(ActiveRecord::RecordNotFound, "No entity for path: #{entity_path.inspect}")
  end

  def resolve_class_or_module(parts)
    fqn = parts.map(&:camelize).join("::")
    source.entity_identities.where(kind: %w[class module]).find_by(fqn: fqn)
  end

  def resolve_method(parts)
    return nil if parts.size < 2
    parent_fqn = parts[0..-2].map(&:camelize).join("::")
    last = parts.last
    scope, slug = last.end_with?(".class") ? ["singleton", last.sub(/\.class\z/, "")] : ["instance", last]
    separator = scope == "singleton" ? "." : "#"
    name = MethodSlug.decode(slug)
    source.entity_identities
          .where(kind: "method", scope: scope)
          .find_by(fqn: "#{parent_fqn}#{separator}#{name}")
  end

  def resolve_attribute(parts)
    return nil if parts.size < 2
    parent_fqn = parts[0..-2].map(&:camelize).join("::")
    source.entity_identities
          .where(kind: "attribute", scope: "instance")
          .find_by(fqn: "#{parent_fqn}##{parts.last}")
  end

  def resolve_constant(parts)
    return nil if parts.size < 2
    parent_fqn = parts[0..-2].map(&:camelize).join("::")
    source.entity_identities
          .where(kind: "constant")
          .find_by(fqn: "#{parent_fqn}::#{parts.last}")
  end

  def source
    current_source
  end
end
