class EntitiesController < ApplicationController
  def show
    @package_version = PackageVersion.find_by!(channel: channel_from_param)
    @identity = resolve_entity!
    @entity_version = @identity.entity_versions.find_by!(package_version: @package_version)
    @presenter = build_presenter
    render template_for(@identity)
  end

  private

  def channel_from_param
    params[:version] == "edge" ? "edge" : params[:version].sub(/\Av/, "")
  end

  # Resolves the URL path to an entity_identity.
  # Tries class/module first, then method (instance + singleton), then
  # constant, then attribute. The first match wins.
  def resolve_entity!
    parts = params[:path].split("/")
    candidate_lookups(parts).each do |candidate|
      identity = source.entity_identities
                       .where(kind: candidate[:kind], scope: candidate[:scope])
                       .find_by(fqn: candidate[:fqn])
      return identity if identity
    end
    raise ActiveRecord::RecordNotFound, "No entity for path: #{params[:path].inspect}"
  end

  def candidate_lookups(parts)
    return [] if parts.empty?

    namespace_fqn = parts.map(&:camelize).join("::")
    parent_fqn = parts[0..-2].map(&:camelize).join("::") if parts.size >= 2
    last = parts.last

    candidates = [
      { kind: %w[class module], fqn: namespace_fqn }
    ]

    if parent_fqn
      method_scope, method_slug = if last.end_with?(".class")
        ["singleton", last.sub(/\.class\z/, "")]
      else
        ["instance", last]
      end
      method_name = MethodSlug.decode(method_slug)
      separator = method_scope == "singleton" ? "." : "#"
      candidates << { kind: "method", fqn: "#{parent_fqn}#{separator}#{method_name}", scope: method_scope }
      candidates << { kind: "attribute", fqn: "#{parent_fqn}##{last}", scope: "instance" }
      candidates << { kind: "constant", fqn: "#{parent_fqn}::#{last}" }
    end

    candidates
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
