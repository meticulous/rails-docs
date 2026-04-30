class EcosystemController < ApplicationController
  def index
    @sources = Source.where.not(slug: "rails")
                     .joins(:package_versions)
                     .where.not(package_versions: { ingested_at: nil })
                     .distinct
                     .order(:display_name)
  end
end
