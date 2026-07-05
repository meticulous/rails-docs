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

    matched = matching(query).joins(:entity_identity)
    matched = if version
      matched.where(package_version: version)
    else
      # Default cross-source scope: current_stable for every source so
      # we don't double-count entities across older Rails versions.
      matched.where(package_version_id: PackageVersion.current_stable_for_each_source.map(&:id))
    end

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
      suggestions: total < 3 ? fuzzy_suggestions(query, version) : [],
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
    if filters[:source].present?
      source_id = Source.where(slug: filters[:source]).limit(1).pick(:id)
      scope = scope.where(entity_identities: { source_id: source_id }) if source_id
    end
    scope
  end

  # For each facet, count results applying every OTHER filter — so the
  # user can see "if I switch to kind=method, that becomes 50 results"
  # without the kind facet's own selection being baked in.
  def compute_facets(matched_scope, filters)
    {
      kind: facet_counts(matched_scope, filters.except(:kind), :kind),
      framework: facet_counts(matched_scope, filters.except(:framework), :framework),
      source: facet_counts(matched_scope, filters.except(:source), :source)
    }
  end

  def facet_counts(matched_scope, filters_minus_self, facet)
    scope = apply_filters(matched_scope, filters_minus_self)
    case facet
    when :kind
      scope.group("entity_identities.kind").count
    when :framework
      scope.left_joins(:framework).group("frameworks.slug").count
    when :source
      scope.joins("JOIN sources ON sources.id = entity_identities.source_id")
           .group("sources.slug").count
    end
  end

  # Exact / prefix name match dominates the ranking. English FTS stems
  # identifiers (`before_action` -> `befor` & `action`), so a plain
  # ts_rank buries the exact method under everything that merely
  # mentions "before" and "action". A big exact-name boost makes
  # searching a method name behave like APIDock / api.rubyonrails.org:
  # the thing you typed comes first, prefix matches next.
  #
  # On top of that, three demotions/boosts keep the doc-body noise out of
  # the top of the list (users on the full-search page reported "junk"):
  #
  # * body-only ×0.4 — a match that landed ONLY in the doc body (D weight),
  #   with nothing in name/signature/summary (A/B/C), is a prose mention,
  #   not the thing itself. `create_table`'s body says "create", but for
  #   the query `create!` the real `#create!` methods must come first. We
  #   detect this by re-ranking with the A/B/C weights zeroed: if that's 0
  #   but the D-only rank is positive, the term appears only in the body.
  # * documented ×1.15 — an entity that actually carries docs beats an
  #   empty stub of the same name. Ecosystem gems reopen Rails classes
  #   (jbuilder's `ActionController`, solid_cache's `ActiveSupport`) with
  #   no docs; this mild boost floats the canonical, documented Rails
  #   definition above those stubs without ever overturning a real match.
  # * private ×0.35 (was 0.5) — internal helpers like
  #   `build_default_constraint` were still surfacing in the top 10 on a
  #   strong body match; a firmer demotion keeps them below public API.
  #
  # The exact clause also matches on the ::-stripped fqn, so a class typed
  # without punctuation (`actioncable` -> ActionCable) exact-matches even
  # when its name lexeme differs from the query.
  def rank_expression(query)
    Arel.sql(
      ApplicationRecord.sanitize_sql([
        "ts_rank_cd(entity_versions.search_vector, websearch_to_tsquery('english', ?), 32) * " \
          "CASE WHEN entity_versions.deprecated THEN 0.4 ELSE 1.0 END * " \
          "CASE WHEN entity_versions.visibility = 'private' THEN 0.35 ELSE 1.0 END * " \
          "CASE " \
          "  WHEN ts_rank_cd('{0,1,1,1}', entity_versions.search_vector, websearch_to_tsquery('english', ?), 32) = 0 " \
          "   AND ts_rank_cd('{0,0,0,1}', entity_versions.search_vector, websearch_to_tsquery('english', ?), 32) > 0 " \
          "  THEN 0.4 ELSE 1.0 " \
          "END * " \
          "CASE WHEN COALESCE(entity_versions.doc_summary, entity_versions.doc_markdown, '') <> '' THEN 1.15 ELSE 1.0 END * " \
          "CASE " \
          "  WHEN lower(entity_identities.name) = lower(?) " \
          "    OR lower(replace(entity_identities.fqn, '::', '')) = lower(replace(?, '::', '')) THEN 100.0 " \
          "  WHEN lower(entity_identities.name) LIKE lower(?) || '%' THEN 8.0 " \
          "  ELSE 1.0 " \
          "END * " \
          "CASE entity_identities.kind " \
          "  WHEN 'method' THEN 1.6 " \
          "  WHEN 'attribute' THEN 1.4 " \
          "  WHEN 'constant' THEN 1.2 " \
          "  ELSE 1.0 " \
          "END DESC",
        query, query, query, query, query, query
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
    scope.order(Arel.sql(ApplicationRecord.sanitize_sql([ "similarity(name, ?) DESC", query ])))
         .limit(8)
         .to_a
  end

  def empty_response(started_at)
    SearchAdapter::Response.new(took_ms: ((Time.now - started_at) * 1000).round)
  end
end
