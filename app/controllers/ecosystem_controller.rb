class EcosystemController < ApplicationController
  def index
    sources = Source.where.not(slug: "rails")
                    .joins(:package_versions)
                    .where.not(package_versions: { ingested_at: nil })
                    .distinct
                    .order(:display_name)

    # `sources.pluck(:id)` here would carry the ORDER BY display_name
    # into the subquery, which Postgres rejects under DISTINCT (the
    # ORDER BY column has to be in the select list). Materialize the
    # ids first with .unscope(:order) so the IN list is plain.
    latest_per_source = PackageVersion
      .where.not(ingested_at: nil)
      .where(source_id: sources.unscope(:order).pluck(:id))
      .select("DISTINCT ON (source_id) package_versions.*")
      .order(:source_id, ord: :desc)
      .index_by(&:source_id)

    entity_counts = EntityVersion
      .where(package_version_id: latest_per_source.values.map(&:id))
      .group(:package_version_id)
      .count

    @entries = sources.map do |source|
      pv = latest_per_source[source.id]
      { source: source, latest: pv, entity_count: entity_counts[pv.id] || 0 }
    end
  end
end
