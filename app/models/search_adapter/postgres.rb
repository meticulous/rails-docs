# Postgres FTS implementation of SearchAdapter. Uses entity_versions.search_vector
# (populated by Loader#refresh_search_vectors) with weighted columns:
# A=name, B=signature/params, C=summary, D=body.
#
# Ranking uses ts_rank_cd (cover-density) and de-boosts deprecated entries.
class SearchAdapter::Postgres
  def search(query:, version: nil, limit: 25, offset: 0)
    started_at = Time.now
    return empty_response(started_at) if query.blank?

    scope = matching(query)
    scope = scope.where(package_version: version) if version

    total = scope.count
    rows = scope
      .preload(entity_identity: :source, package_version: {}, framework: {})
      .order(rank_expression(query))
      .limit(limit)
      .offset(offset)
      .to_a

    SearchAdapter::Response.new(
      results: rows.map { |ev| SearchAdapter::Result.new(entity_version: ev) },
      total: total,
      took_ms: ((Time.now - started_at) * 1000).round
    )
  end

  def healthcheck
    EntityVersion.where.not(search_vector: nil).limit(1).exists?
  end

  private

  def matching(query)
    EntityVersion.where("search_vector @@ websearch_to_tsquery('english', ?)", query)
  end

  def rank_expression(query)
    Arel.sql(
      ApplicationRecord.send(:sanitize_sql_array, [
        "ts_rank_cd(search_vector, websearch_to_tsquery('english', ?), 32) * " \
          "CASE WHEN deprecated THEN 0.4 ELSE 1.0 END DESC",
        query
      ])
    )
  end

  def empty_response(started_at)
    SearchAdapter::Response.new(
      results: [], total: 0, took_ms: ((Time.now - started_at) * 1000).round
    )
  end
end
