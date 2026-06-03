# Renders an entity_version as a clean Markdown document for AI agents
# and any client that asks for text/markdown (or appends `.md` to the
# URL). The doc body is already stored as Markdown at ingest; this wraps
# it with a compact, machine-friendly header — title, metadata, signature,
# source link, and the version availability strip.
class EntityMarkdown
  def initialize(entity_version)
    @ev = entity_version
    @id = entity_version.entity_identity
    @pv = entity_version.package_version
  end

  def to_s
    [ heading, metadata, signature, body, availability, source ].compact.join("\n\n") + "\n"
  end

  private

  def heading
    "# #{@id.fqn}"
  end

  def metadata
    bits = []
    bits << kind_label
    bits << @ev.framework.display_name if @ev.framework
    bits << "#{@pv.source.display_name} #{@pv.channel}"
    bits << "**deprecated**" if @ev.try(:deprecated)
    bits << "private" if @ev.visibility == "private"
    bits.join(" · ")
  end

  def kind_label
    case @id.kind
    when "method"    then @id.scope == "singleton" ? "class method" : "instance method"
    when "attribute" then "attribute"
    else @id.kind
    end
  end

  def signature
    sig = @ev.try(:call_seq).presence || @ev.try(:signature_text).presence
    return nil unless sig
    "```ruby\n#{sig.strip}\n```"
  end

  def body
    md = @ev.doc_markdown.presence
    md ? md.strip : "_No documentation comment._"
  end

  def availability
    # The versions this entity actually exists in (not every ingested
    # version), oldest→newest, scoped to its own source.
    versions = @id.available_versions.distinct.order(:ord).to_a
    return nil if versions.size < 2
    "**Available in:** " + versions.map { |v| "v#{v.channel}" }.join(", ")
  end

  def source
    url = @ev.try(:github_source_url)
    url ? "[Source](#{url})" : nil
  end
end
