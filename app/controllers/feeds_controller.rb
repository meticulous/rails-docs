# Per-framework Atom feed of recent additions. Lists entities whose
# first_seen_version is the current_stable PackageVersion — i.e. "what's
# new in this Rails release for this framework". v2 enrichment: include
# removals (last_seen_version older than current_stable), changed
# signatures, etc.
class FeedsController < ApplicationController
  def framework
    source = Source.find_by!(slug: "rails")
    @framework = source.frameworks.find_by!(slug: params[:framework_slug])
    @latest_version = PackageVersion.current_stable

    return head :not_found unless @latest_version

    @changes = EntityIdentity
      .where(framework: @framework, first_seen_version: @latest_version)
      .order(:fqn)
      .limit(100)

    respond_to { |f| f.atom }
  end
end
