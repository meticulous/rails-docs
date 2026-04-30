xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.urlset(xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9") do
  @entities.find_each do |entity_version|
    xml.url do
      xml.loc url_for(controller: "entities", action: "show",
                       version: version_url_segment(@package_version),
                       path: entity_url_path(entity_version.entity_identity),
                       only_path: false)
      xml.lastmod entity_version.updated_at.iso8601
      xml.priority "0.8"
    end
  end
end
