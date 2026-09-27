# Per-entity Open Graph / Twitter card image. Rendered as SVG at request
# time; we'd reach for image_processing + libvips if a PNG fallback
# becomes necessary (Twitter and Facebook prefer PNG; Slack, Mastodon,
# Discord all render SVG).
class OgImagesController < ApplicationController
  include EntityResolution

  def show
    @package_version = requested_package_version
    @identity = resolve_entity!(params[:path].to_s.delete_suffix(".svg"), @package_version)
    @entity_version = @identity.entity_versions.find_by(package_version: @package_version)

    response.headers["Cache-Control"] = "public, max-age=86400"
    render template: "og_images/show", formats: [ :svg ]
  end
end
