xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.urlset(xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9") do
  source_slug = current_source.slug == "rails" ? nil : current_source.slug

  @entities.find_each do |entity_version|
    xml.url do
      xml.loc entity_url(
        source_slug: source_slug,
        version: version_url_segment(@package_version),
        path: entity_url_path(entity_version.entity_identity)
      )
      xml.lastmod entity_version.updated_at.iso8601
      xml.priority "0.8"
    end
  end
end
