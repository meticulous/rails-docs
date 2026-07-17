# The structured twin of EntityMarkdown: renders an entity_version as a
# JSON payload for agents and tooling that want fields rather than prose.
# Served by EntitiesController when the URL carries a `.json` suffix or
# the request accepts application/json.
class EntityJson
  def initialize(entity_version)
    @ev = entity_version
    @id = entity_version.entity_identity
    @pv = entity_version.package_version
  end

  def as_json
    {
      fqn: @id.fqn,
      name: @id.name,
      kind: @id.kind,
      scope: @id.scope,
      visibility: @ev.visibility,
      deprecated: @ev.try(:deprecated) || false,
      framework: @ev.framework&.display_name,
      source: { name: @pv.source.display_name, slug: @pv.source.slug, version: @pv.channel },
      signature: @ev.try(:signature_text),
      call_seq: @ev.try(:call_seq),
      params: params_payload,
      doc_summary: @ev.doc_summary,
      doc_markdown: @ev.doc_markdown,
      available_in: @id.available_versions.distinct.order(:ord).map { |v| "v#{v.channel}" },
      source_path: @ev.source_path,
      source_line: @ev.source_line_start,
      github_url: @ev.try(:github_source_url),
      urls: { html: page_path, markdown: "#{page_path}.md", json: "#{page_path}.json" }
    }.compact
  end

  private

  def params_payload
    return nil unless @id.kind == "method"
    @ev.method_params.map do |p|
      { name: p.name, kind: p.kind, default: p.default_expr, doc: p.doc }.compact
    end
  end

  # Version-scoped path built the same way CrossrefLinker does it —
  # EntityIdentity#entity_url_path is the single source of truth for
  # slug shapes.
  def page_path
    @page_path ||= begin
      segment = @pv.channel == "edge" ? "edge" : "v#{@pv.channel}"
      prefix = @pv.source.slug == "rails" ? "" : "/#{@pv.source.slug}"
      "#{prefix}/#{segment}/#{@id.entity_url_path}"
    end
  end
end
