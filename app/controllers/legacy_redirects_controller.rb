# 301 redirects from the old sdoc URL shape (the api.rubyonrails.org we are
# replacing). Two cases:
#
#   /classes/ActiveRecord/Persistence.html         → class/module page
#   /files/activerecord/lib/active_record/...      → no first-class equivalent;
#                                                    redirect to home
#
# Method anchors like #method-i-save can't be seen by the server (fragments
# aren't sent), so the client-side redirect to the per-method page happens
# in app/javascript/controllers/legacy_anchor_controller.js, which fires on
# the destination class page.
class LegacyRedirectsController < ApplicationController
  def class_show
    fqn = sdoc_path_to_fqn(params[:sdoc_path])
    identity = Source.find_by!(slug: "rails")
                     .entity_identities
                     .where(kind: %w[class module])
                     .find_by(fqn: fqn)

    return head :not_found unless identity && current_stable

    redirect_to entity_path(version: version_segment(current_stable), path: identity.url_path),
                status: :moved_permanently
  end

  def file_show
    return head :not_found unless current_stable
    redirect_to root_path, status: :moved_permanently
  end

  # Client-side companion: legacy_anchor_controller.js parses
  # #method-(i|c)-NAME and redirects here so the server can look up the
  # method in the rails-docs DB and 301 to the per-method page. We decode
  # MethodSlug here because the JS controller doesn't know the encoding.
  def method_redirect
    parent_path = params[:parent_path].to_s
    name = params[:name].to_s
    scope = params[:scope] == "singleton" ? "singleton" : "instance"

    return head :not_found if name.empty? || parent_path.empty?

    slug = MethodSlug.encode(name)
    slug = "#{slug}.class" if scope == "singleton"
    redirect_to "#{parent_path.chomp('/')}/#{slug}", status: :moved_permanently
  end

  private

  def sdoc_path_to_fqn(path)
    path.to_s.delete_suffix(".html").split("/").join("::")
  end

  def current_stable
    @current_stable ||= PackageVersion
      .where.not(ingested_at: nil)
      .where(prerelease: [nil, ""])
      .order(ord: :desc)
      .first
  end

  def version_segment(pv)
    pv.channel == "edge" ? "edge" : "v#{pv.channel}"
  end
end
