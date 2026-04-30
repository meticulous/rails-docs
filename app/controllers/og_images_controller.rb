# Per-entity Open Graph / Twitter card image. Rendered as SVG at request
# time; we'd reach for image_processing + libvips if a PNG fallback
# becomes necessary (Twitter and Facebook prefer PNG; Slack, Mastodon,
# Discord all render SVG).
class OgImagesController < ApplicationController
  def show
    @package_version = current_source.package_versions.find_by!(channel: channel_from_param)
    @identity = resolve_entity!(params[:path])
    @entity_version = @identity.entity_versions.find_by(package_version: @package_version)

    response.headers["Cache-Control"] = "public, max-age=86400"
    render template: "og_images/show", formats: [:svg]
  end

  private

  def channel_from_param
    params[:version] == "edge" ? "edge" : params[:version].sub(/\Av/, "")
  end

  def resolve_entity!(path)
    parts = path.to_s.delete_suffix(".svg").split("/")
    raise ActiveRecord::RecordNotFound if parts.empty?

    fqn = parts.map(&:camelize).join("::")
    identity = source.entity_identities.where(kind: %w[class module]).find_by(fqn: fqn)
    return identity if identity

    if parts.size >= 2
      parent_fqn = parts[0..-2].map(&:camelize).join("::")
      last = parts.last
      scope, slug = last.end_with?(".class") ? ["singleton", last.sub(/\.class\z/, "")] : ["instance", last]
      separator = scope == "singleton" ? "." : "#"
      identity = source.entity_identities
                       .where(kind: "method", scope: scope)
                       .find_by(fqn: "#{parent_fqn}#{separator}#{MethodSlug.decode(slug)}")
      return identity if identity

      identity = source.entity_identities
                       .where(kind: "constant")
                       .find_by(fqn: "#{parent_fqn}::#{parts.last}")
      return identity if identity
    end

    raise ActiveRecord::RecordNotFound, "No entity for #{path.inspect}"
  end

  def source
    current_source
  end
end
