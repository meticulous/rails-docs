# Postgres FTS implementation of SearchAdapter. Uses entity_versions.search_vector
# (populated by Loader#refresh_search_vectors) with weighted columns:
# A=name, B=signature/params, C=summary, D=body.
#
# Ranking uses ts_rank_cd (cover-density) with a kind-aware boost so methods
# rank above modules for method-name queries; deprecated entries are de-boosted.
class SearchAdapter::Postgres
  def search(query:, version: nil, filters: {}, limit: 25, offset: 0)
    started_at = Time.now
    return empty_response(started_at) if query.blank?

    effective_version = version || PackageVersion.current_stable
    matched = matching(query).joins(:entity_identity)
    matched = matched.where(package_version: effective_version) if effective_version

    filtered = apply_filters(matched, filters)

    total = filtered.count
    rows = filtered
      .preload(entity_identity: :source, package_version: {}, framework: {})
      .order(rank_expression(query))
      .limit(limit)
      .offset(offset)
      .to_a

    SearchAdapter::Response.new(
      results: rows.map { |ev| SearchAdapter::Result.new(entity_version: ev) },
      total: total,
      facets: compute_facets(matched, filters),
      suggestions: total < 3 ? fuzzy_suggestions(query, effective_version) : [],
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

  def apply_filters(scope, filters)
    scope = scope.where(entity_identities: { kind: filters[:kind] }) if filters[:kind].present?
    scope = scope.where(framework: { slug: filters[:framework] }) if filters[:framework].present?
    scope
  end

  # For each facet, count results applying every OTHER filter — so the
  # user can see "if I switch to kind=method, that becomes 50 results"
  # without the kind facet's own selection being baked in.
  def compute_facets(matched_scope, filters)
    {
      kind: facet_counts(matched_scope, filters.except(:kind), :kind),
      framework: facet_counts(matched_scope, filters.except(:framework), :framework)
    }
  end

  def facet_counts(matched_scope, filters_minus_self, facet)
    scope = apply_filters(matched_scope, filters_minus_self)
    case facet
    when :kind
      scope.group("entity_identities.kind").count
    when :framework
      scope.left_joins(:framework).group("frameworks.slug").count
    end
  end

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

  # Trigram-similarity suggestions used when FTS returns < 3 hits. Ranks
  # entity_identities by similarity(name, query) above pg_trgm's default
  # threshold (0.3); typically catches "sav" → "save", "save" → "save!",
  # "wjere" → "where". Limited to 8 to avoid drowning the page.
  def fuzzy_suggestions(query, version)
    scope = EntityIdentity.where("name % ?", query)
    if version
      scope = scope.where(id: EntityVersion.where(package_version: version).select(:entity_identity_id))
    end
    scope.order(Arel.sql(ApplicationRecord.send(:sanitize_sql_array, ["similarity(name, ?) DESC", query])))
         .limit(8)
         .to_a
  end

  def empty_response(started_at)
    SearchAdapter::Response.new(took_ms: ((Time.now - started_at) * 1000).round)
  end
end
