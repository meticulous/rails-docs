class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_source, :nav_package_version, :current_framework_slug

  # Resolves the Source from params[:source_slug], defaulting to rails
  # when the route doesn't carry one. Controllers fetching entity data
  # go through this rather than hard-coding "rails".
  def current_source
    @current_source ||= Source.find_by!(slug: params[:source_slug] || "rails")
  end

  # The PackageVersion the persistent left module-nav should reflect.
  # Pages that already set @package_version (entity, version, og_images,
  # diff) carry that version through; everything else (home, search,
  # ecosystem, errors) falls back to current_source.current_stable.
  def nav_package_version
    @nav_package_version ||= @package_version || current_source.current_stable
  end

  # Slug of the framework the current page belongs to (when there is
  # one) so the module-nav can expand the matching section by default.
  # Class/module/method/etc. pages set @entity_version on the controller;
  # we read its framework slug from there.
  def current_framework_slug
    return @current_framework_slug if defined?(@current_framework_slug)
    @current_framework_slug = @entity_version&.framework&.slug ||
      @identity&.framework&.slug
  end
end
