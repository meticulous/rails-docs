class EntitiesController < ApplicationController
  include EntityResolution

  before_action :load_available_versions

  def show
    @package_version = requested_package_version
    @markdown = markdown_requested?
    @json = !@markdown && json_requested?
    @identity = resolve_entity!(entity_path_param, @package_version)
    @entity_version = @identity.entity_versions.find_by(package_version: @package_version)

    if @markdown
      return head :not_found unless @entity_version
      render plain: EntityMarkdown.new(@entity_version).to_s,
             content_type: "text/markdown"
    elsif @json
      return head :not_found unless @entity_version
      render json: EntityJson.new(@entity_version).as_json
    elsif @entity_version
      @presenter = build_presenter
      render template_for(@identity)
    else
      render "entities/missing", status: :not_found
    end
  end

  # Version-less URLs (the stable link shape llms.txt advertises):
  # 302 to the same path under the source's current stable. 302, not
  # 301 — the target moves with every release, so nothing may cache it.
  # The leading path segment doubles as an ecosystem source slug
  # (/turbo-rails/turbo/streams_channel); anything else is a rails path.
  def current_stable
    segments = params[:path].to_s.split("/")
    src = Source.find_by(slug: segments.first)
    path = src ? segments.drop(1).join("/") : params[:path]
    src ||= Source.find_by!(slug: "rails")

    stable = src.current_stable
    raise ActiveRecord::RecordNotFound if stable.nil? || path.blank?
    redirect_to entity_path(source_slug: (src.slug unless src.slug == "rails"),
                            version: helpers.version_url_segment(stable),
                            path: path),
                status: :found
  end

  private

  def load_available_versions
    @available_versions = current_source.package_versions.where.not(ingested_at: nil).order(ord: :desc)
  end

  # An AI agent can fetch the clean, structured doc for any entity by
  # appending `.md` to the URL or sending `Accept: text/markdown` —
  # no 96%-navigation HTML, no JS. The `.md` suffix is stripped before
  # entity resolution.
  def markdown_requested?
    request.format.to_s.include?("markdown") ||
      request.headers["Accept"].to_s.include?("text/markdown") ||
      params[:path].to_s.end_with?(".md")
  end

  # Same affordance as markdown, but structured: `.json` or
  # `Accept: application/json` returns the entity as fields (EntityJson)
  # instead of prose.
  def json_requested?
    params[:path].to_s.end_with?(".json") ||
      request.headers["Accept"].to_s.include?("application/json")
  end

  def entity_path_param
    path = params[:path].to_s
    path = path.delete_suffix(".md") if @markdown
    path = path.delete_suffix(".json") if @json
    path
  end

  def build_presenter
    case @identity.kind
    when "class", "module" then ClassPresenter.new(@entity_version)
    when "method" then MethodPresenter.new(@entity_version)
    else ClassPresenter.new(@entity_version) # constants/attributes reuse the class layout for now
    end
  end

  def template_for(identity)
    case identity.kind
    when "method" then "entities/method"
    else "entities/class"
    end
  end
end
