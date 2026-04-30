class HomeController < ApplicationController
  def index
    @package_versions = PackageVersion.ok.where.not(ingested_at: nil).order(ord: :desc)
    @current_stable = current_source.current_stable

    if @current_stable
      @frameworks = current_source.frameworks
                                  .joins(:entity_versions)
                                  .where(entity_versions: { package_version_id: @current_stable.id })
                                  .group("frameworks.id")
                                  .order(:slug)
                                  .select("frameworks.*, COUNT(entity_versions.id) AS entity_count")

      fqns = @frameworks.map(&:top_module_fqn)
      @top_modules_by_fqn = current_source.entity_identities
                                          .where(kind: %w[module class], fqn: fqns)
                                          .index_by(&:fqn)
    else
      @frameworks = []
      @top_modules_by_fqn = {}
    end
  end
end
