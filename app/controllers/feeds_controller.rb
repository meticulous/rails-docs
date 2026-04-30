# Per-framework Atom feed of recent additions. Lists entities whose
# first_seen_version is the current_stable PackageVersion — i.e. "what's
# new in this Rails release for this framework". v2 enrichment: include
# removals (last_seen_version older than current_stable), changed
# signatures, etc.
class FeedsController < ApplicationController
  # Per-framework feed (rails-only — frameworks belong to the rails source).
  #   /feeds/activerecord  → "What's new in Active Record vX.Y.Z"
  def framework
    @source = Source.find_by!(slug: "rails")
    @framework = @source.frameworks.find_by!(slug: params[:framework_slug])
    @scope_label = @framework.display_name
    @latest_version = source_current_stable(@source)

    return head :not_found unless @latest_version

    @changes = build_changes(@latest_version, framework: @framework)
    @removals = build_removals(@latest_version, framework: @framework)

    respond_to { |f| f.atom { render :show } }
  end

  # Per-source feed for non-rails ecosystem gems (no framework concept).
  #   /feeds/sources/turbo-rails  → "What's new in Turbo Rails vX.Y.Z"
  def source
    @source = Source.find_by!(slug: params[:source_slug])
    @scope_label = @source.display_name
    @latest_version = source_current_stable(@source)

    return head :not_found unless @latest_version

    @changes = build_changes(@latest_version, framework: nil, source: @source)
    @removals = build_removals(@latest_version, framework: nil, source: @source)

    respond_to { |f| f.atom { render :show } }
  end

  private

  def source_current_stable(source)
    source.package_versions
          .where.not(ingested_at: nil)
          .where(prerelease: [nil, ""])
          .order(ord: :desc)
          .first
  end

  def build_changes(latest, framework: nil, source: nil)
    scope = EntityIdentity.where(first_seen_version: latest)
    scope = scope.where(framework: framework) if framework
    scope = scope.where(source: source) if source
    scope.order(:fqn).limit(100)
  end

  def build_removals(latest, framework: nil, source: nil)
    previous = latest.source.package_versions
                           .where.not(ingested_at: nil)
                           .where("ord < ?", latest.ord)
                           .order(ord: :desc)
                           .first
    return EntityIdentity.none unless previous

    scope = EntityIdentity.where(last_seen_version: previous).includes(:last_seen_version)
    scope = scope.where(framework: framework) if framework
    scope = scope.where(source: source) if source
    scope.order(:fqn).limit(100)
  end
end
