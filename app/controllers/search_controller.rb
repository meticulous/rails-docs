class SearchController < ApplicationController
  RESULTS_PER_PAGE = 30

  def index
    @query = params[:q].to_s.strip
    @version = resolve_version
    @response = if @query.present?
      SearchAdapter.current.search(query: @query, version: @version, limit: RESULTS_PER_PAGE)
    end
  end

  private

  def resolve_version
    return nil if params[:version].blank?
    channel = params[:version] == "edge" ? "edge" : params[:version].sub(/\Av/, "")
    PackageVersion.find_by(channel: channel)
  end
end
