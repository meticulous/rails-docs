class EntitiesController < ApplicationController
  before_action :load_available_versions

  def show
    @package_version = PackageVersion.find_by!(channel: channel_from_param)
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
    @source ||= Source.find_by!(slug: "rails")
  end
end
