class EntitiesController < ApplicationController
  def show
    channel = params[:version] == "edge" ? "edge" : params[:version].sub(/\Av/, "")
    @package_version = PackageVersion.find_by!(channel: channel)
    @identity = resolve_class_or_module!
    @entity_version = @identity.entity_versions.find_by!(package_version: @package_version)
    @presenter = ClassPresenter.new(@entity_version)
  end

  private

  def resolve_class_or_module!
    fqn = params[:path].split("/").map(&:camelize).join("::")
    Source.find_by!(slug: "rails")
          .entity_identities
          .where(kind: %w[class module])
          .find_by!(fqn: fqn)
  end
end
