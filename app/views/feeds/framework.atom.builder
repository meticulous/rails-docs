atom_feed language: "en" do |feed|
  feed.title("What's new in #{@framework.display_name} #{@latest_version.channel}")
  feed.updated(@latest_version.released_on || @latest_version.ingested_at)

  @changes.each do |identity|
    feed.entry(identity,
               url: entity_url(version: version_url_segment(@latest_version), path: identity.url_path),
               id: "tag:#{request.host},#{@latest_version.channel}:#{identity.id}",
               updated: @latest_version.released_on || @latest_version.ingested_at) do |entry|
      entry.title("Added: #{identity.fqn}")
      entry.content("New #{identity.kind} in Ruby on Rails #{@latest_version.channel}.", type: "text")
      entry.author { |a| a.name "Rails Foundation" }
    end
  end
end
