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
    @nav_package_version = current_source.package_versions.where.not(ingested_at: nil)
                                         .find_by!(channel: params[:version].delete_prefix("v"))
    @ecosystem_versions = include_ecosystem? ? ecosystem_versions : []
    expires_in 1.hour, public: true
    render layout: false
  end

  private

  # The /ecosystem variant appends every ecosystem gem's tree (at its own
  # current stable) below the Rails framework groups. Only meaningful on
  # the rails nav — an ecosystem gem's own nav already shows that gem.
  def include_ecosystem?
    params[:ecosystem] && current_source.slug == "rails"
  end

  def ecosystem_versions
    Source.where.not(slug: "rails").order(:display_name).filter_map(&:current_stable)
  end
end
