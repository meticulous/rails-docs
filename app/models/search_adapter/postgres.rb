# Postgres FTS implementation of SearchAdapter. Uses entity_versions.search_vector
# (populated by Loader#refresh_search_vectors) with weighted columns:
# A=name, B=signature/params, C=summary, D=body.
#
# Ranking uses ts_rank_cd (cover-density) and de-boosts deprecated entries.
class SearchAdapter::Postgres
  def search(query:, version: nil, limit: 25, offset: 0)
    started_at = Time.now
    return empty_response(started_at) if query.blank?

    scope = matching(query).joins(:entity_identity)
    # Default to current_stable so searches don't surface duplicates
    # across versions. Explicit `version:` overrides, supporting the
    # version-scoped search UI.
    effective_version = version || PackageVersion.current_stable
    scope = scope.where(package_version: effective_version) if effective_version

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

  # Kind-aware boost: methods, attributes, and constants are typically what
  # users search for ("has_many", "save", "find_by"); modules and classes
  # are reachable via search but shouldn't outrank a method whose name
  # exactly matches the query just because the module's body mentions it
  # often. Multipliers are intentionally modest so a strong-name match
  # on a class still beats a weak body match on a method.
  def rank_expression(query)
    Arel.sql(
      ApplicationRecord.send(:sanitize_sql_array, [
        "ts_rank_cd(entity_versions.search_vector, websearch_to_tsquery('english', ?), 32) * " \
          "CASE WHEN entity_versions.deprecated THEN 0.4 ELSE 1.0 END * " \
          "CASE entity_identities.kind " \
          "  WHEN 'method' THEN 1.6 " \
          "  WHEN 'attribute' THEN 1.4 " \
          "  WHEN 'constant' THEN 1.2 " \
          "  ELSE 1.0 " \
          "END DESC",
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
