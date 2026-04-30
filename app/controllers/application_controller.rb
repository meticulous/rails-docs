class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_source

  # Resolves the Source from params[:source_slug], defaulting to rails
  # when the route doesn't carry one. Controllers fetching entity data
  # go through this rather than hard-coding "rails".
  def current_source
    @current_source ||= Source.find_by!(slug: params[:source_slug] || "rails")
  end
end
