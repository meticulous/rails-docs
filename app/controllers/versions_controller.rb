class VersionsController < ApplicationController
  def show
    @package_version = current_source.package_versions.find_by!(channel: channel_from_param)
    @available_versions = PackageVersion.where.not(ingested_at: nil).order(ord: :desc)
    @frameworks = @package_version.entity_versions
                                   .joins(:framework)
                                   .group("frameworks.id", "frameworks.slug", "frameworks.display_name")
                                   .order("frameworks.slug")
                                   .pluck("frameworks.slug", "frameworks.display_name", Arel.sql("COUNT(*) AS entity_count"))
  end

  private

  def channel_from_param
    params[:version] == "edge" ? "edge" : params[:version].sub(/\Av/, "")
  end
end
