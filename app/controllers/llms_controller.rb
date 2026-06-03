# Serves /llms.txt — the emerging convention for pointing AI crawlers and
# agents at a site's machine-readable content. Rendered dynamically so the
# current stable version and framework list stay accurate after each
# ingest, rather than drifting in a checked-in static file.
class LlmsController < ApplicationController
  def show
    @stable = Source.find_by(slug: "rails")&.current_stable
    @frameworks =
      if @stable
        @stable.source.frameworks
               .joins(:entity_versions)
               .where(entity_versions: { package_version_id: @stable.id })
               .distinct.order(:slug)
      else
        Framework.none
      end
    expires_in 6.hours, public: true
    render layout: false, content_type: "text/plain"
  end
end
