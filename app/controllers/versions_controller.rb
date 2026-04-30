class VersionsController < ApplicationController
  def show
    @package_version = current_source.package_versions.find_by!(channel: channel_from_param)
    @available_versions = PackageVersion.where.not(ingested_at: nil).order(ord: :desc)

    @frameworks = current_source.frameworks
                                .joins(:entity_versions)
                                .where(entity_versions: { package_version_id: @package_version.id })
                                .group("frameworks.id")
                                .order(:slug)
                                .select("frameworks.*, COUNT(entity_versions.id) AS entity_count")

    fqns = @frameworks.map(&:top_module_fqn)
    @top_modules_by_fqn = current_source.entity_identities
                                        .where(kind: %w[module class], fqn: fqns)
                                        .index_by(&:fqn)
  end

  private

  def channel_from_param
    params[:version] == "edge" ? "edge" : params[:version].sub(/\Av/, "")
  end
end
