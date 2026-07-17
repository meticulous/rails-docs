# Nightly new-release check (scheduled in config/recurring.yml): fetch
# the rails clone's tags and ingest any stable release we don't have —
# the newest patch of each minor series, including security releases on
# older supported series (7.1.5 → 7.1.5.1). Release-candidate and beta
# tags never match. Idempotent: an already-ingested channel is skipped,
# so a quiet night costs one git fetch.
class RefreshStableJob < ApplicationJob
  include RailsRepo

  queue_as :ingest

  # v8.1.3 or v6.1.7.10 — never v8.2.0.rc1 / v8.2.0.beta1.
  STABLE_TAG = /\Av(\d+)\.(\d+)\.(\d+)(?:\.(\d+))?\z/

  def perform
    git("fetch", "--quiet", "--tags", upstream_url)

    latest_tag_per_series.each do |series, tag|
      next if (series <=> oldest_tracked_series).negative?

      channel = tag.delete_prefix("v")
      next if existing_channels.include?(channel)

      Rails.logger.info "[stable] new release #{tag}, enqueueing ingest"
      IngestPackageVersionJob.perform_later(
        source_slug: "rails",
        channel: channel,
        git_ref: tag,
        git_sha: git("rev-parse", "--short=10", tag).strip,
        ord: ord_for(tag),
        source_dirs: RefreshEdgeJob::SOURCE_DIRS
      )
    end
  end

  private

  # { [8, 1] => "v8.1.3", [8, 0] => "v8.0.5", ... } — newest tag of each
  # minor series, by version comparison (so v8.1.10 beats v8.1.9).
  def latest_tag_per_series
    git("tag", "--list", "v*").lines.map(&:strip)
      .select { |tag| tag.match?(STABLE_TAG) }
      .group_by { |tag| tag.match(STABLE_TAG).captures.first(2).map(&:to_i) }
      .transform_values { |tags| tags.max_by { |tag| Gem::Version.new(tag.delete_prefix("v")) } }
  end

  # Only series we already track (or newer) get auto-ingested — EOL
  # series before the backfill floor stay out.
  def oldest_tracked_series
    @oldest_tracked_series ||= existing_channels
      .map { |channel| channel.split(".").first(2).map(&:to_i) }
      .min || [ 0, 0 ]
  end

  def existing_channels
    @existing_channels ||= Source.find_by(slug: "rails")
      &.package_versions&.where.not(channel: "edge")&.pluck(:channel) || []
  end

  # Matches the backfill's ord scheme: major*1e6 + minor*1e3 + patch,
  # fourth segment dropped (6.1.7.10 → 6001007) — consistency with the
  # existing rows matters more than encoding the tiny version.
  def ord_for(tag)
    major, minor, patch = tag.match(STABLE_TAG).captures.first(3).map(&:to_i)
    (major * 1_000_000) + (minor * 1_000) + patch
  end
end
