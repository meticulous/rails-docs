xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.sitemapindex(xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9") do
  @package_versions.each do |pv|
    xml.sitemap do
      slug = pv.source.slug
      xml.loc version_sitemap_url(
        source_slug: (slug == "rails" ? nil : slug),
        version: version_url_segment(pv)
      )
      xml.lastmod pv.ingested_at.iso8601 if pv.ingested_at
    end
  end
end
