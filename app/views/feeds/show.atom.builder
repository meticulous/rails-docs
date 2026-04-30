atom_feed language: "en" do |feed|
  feed.title("What's new in #{@scope_label} #{@latest_version.channel}")
  feed.updated(@latest_version.released_on || @latest_version.ingested_at)

  @changes.each do |identity|
    feed.entry(identity,
               url: entity_url(version: version_url_segment(@latest_version),
                               source_slug: (@source.slug if @source.slug != "rails"),
                               path: identity.url_path),
               id: "tag:#{request.host},#{@latest_version.channel}:added:#{identity.id}",
               updated: @latest_version.released_on || @latest_version.ingested_at) do |entry|
      entry.title("Added: #{identity.fqn}")
      entry.content("New #{identity.kind} in #{@scope_label} #{@latest_version.channel}.", type: "text")
      entry.author { |a| a.name "Rails Foundation" }
    end
  end

  @removals.each do |identity|
    feed.entry(identity,
               url: entity_url(version: version_url_segment(identity.last_seen_version),
                               source_slug: (@source.slug if @source.slug != "rails"),
                               path: identity.url_path),
               id: "tag:#{request.host},#{@latest_version.channel}:removed:#{identity.id}",
               updated: @latest_version.released_on || @latest_version.ingested_at) do |entry|
      entry.title("Removed: #{identity.fqn}")
      entry.content("#{identity.kind.capitalize} removed in #{@scope_label} #{@latest_version.channel}; last seen in v#{identity.last_seen_version.channel}.", type: "text")
      entry.author { |a| a.name "Rails Foundation" }
    end
  end
end
