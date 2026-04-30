class SitemapsController < ApplicationController
  # Per-version partition. /sitemap.xml is the index of per-version sitemaps.
  # /v8.1.2/sitemap.xml lists all entity URLs for that version.
  #
  # Stays well under Google's 50k-URL-per-sitemap cap; current rails 8.1.2
  # ingest produces ~8.5k entity URLs per version.

  def index
    @package_versions = PackageVersion.where.not(ingested_at: nil).order(ord: :desc)
    respond_to { |f| f.xml }
  end

  def show
    @package_version = PackageVersion.find_by!(channel: channel_from_param)
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
