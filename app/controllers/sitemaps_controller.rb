class SitemapsController < ApplicationController
  # Per-source-and-version partition. /sitemap.xml is the index of every
  # ingested (source, version) pair; /:source_slug/:version/sitemap.xml
  # (or /:version/sitemap.xml for rails) lists that pair's entity URLs.
  #
  # Stays well under Google's 50k-URL-per-sitemap cap; the largest single
  # version (rails 8.1.2) is ~8.5k entity URLs.

  def index
    @package_versions = PackageVersion.where.not(ingested_at: nil)
                                       .preload(:source)
                                       .order(ord: :desc)
    respond_to { |f| f.xml }
  end

  def show
    @package_version = current_source.package_versions.find_by!(channel: channel_from_param)
    @entities = @package_version.entity_versions
                                 .preload(:entity_identity)
                                 .order(:id)
    respond_to { |f| f.xml }
  end

  private

  def channel_from_param
    params[:version] == "edge" ? "edge" : params[:version].sub(/\Av/, "")
  end
end
