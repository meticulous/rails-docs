class SearchController < ApplicationController
  RESULTS_PER_PAGE = 30
  SUGGEST_LIMIT = 8

  def index
    @query = params[:q].to_s.strip
    @version = resolve_version
    @filters = filters_from_params
    @response = if @query.present?
      SearchAdapter.current.search(
        query: @query,
        version: @version,
        filters: @filters,
        limit: RESULTS_PER_PAGE
      )
    end
  end

  # JSON typeahead for the ⌘K palette. Returns slim entity descriptors
  # (fqn, kind, summary, url) — no doc body, no pagination.
  def suggest
    query = params[:q].to_s.strip
    if query.length < 2
      render json: { results: [], total: 0 }
      return
    end

    response = SearchAdapter.current.search(
      query: query,
      version: resolve_version,
      limit: SUGGEST_LIMIT
    )

    render json: {
      results: response.results.map { |r| serialize(r.entity_version) },
      total: response.total,
      took_ms: response.took_ms
    }
  end

  private

  def resolve_version
    return nil if params[:version].blank?
    channel = params[:version] == "edge" ? "edge" : params[:version].sub(/\Av/, "")
    PackageVersion.find_by(channel: channel)
  end

  def filters_from_params
    {
      kind: params[:kind].presence,
      framework: params[:framework].presence
    }.compact
  end

  def serialize(entity_version)
    {
      fqn: entity_version.fqn,
      kind: entity_version.kind,
      scope: entity_version.scope,
      summary: entity_version.doc_summary&.truncate(140),
      url: helpers.entity_path_for(entity_version.entity_identity, entity_version.package_version)
    }
  end
end
