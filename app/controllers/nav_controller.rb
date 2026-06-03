# Serves the persistent left module-nav as a lazy-loaded turbo-frame.
#
# Pulling the 1,500-node namespace tree out of the per-page HTML and into
# a separate frame keeps content pages content-first: the document an AI
# crawler (or a no-JS client) fetches is the documentation, not 96%
# navigation chrome. The frame is data-turbo-permanent on the page side,
# so it loads once per session and persists across navigations.
#
# The response is version-scoped only (no per-page active context); the
# active-row highlight is applied client-side from <meta> tags so this
# fragment caches as one blob per (source, version).
class NavController < ApplicationController
  def show
    @nav_package_version = resolve_package_version
    expires_in 1.hour, public: true
    render layout: false
  end

  private

  def resolve_package_version
    source = Source.find_by(slug: params[:source_slug].presence || "rails") || current_source
    if params[:version].present?
      channel = params[:version] == "edge" ? "edge" : params[:version].sub(/\Av/, "")
      source.package_versions.where.not(ingested_at: nil).find_by(channel: channel) || source.current_stable
    else
      source.current_stable
    end
  end
end
