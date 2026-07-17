require "open3"

# Nightly edge refresh (scheduled in config/recurring.yml): fetch the
# rails clone, and when main's tip has moved, re-ingest it as the "edge"
# channel. Idempotent by SHA — a quiet night (or a rerun) costs one
# git fetch and nothing else.
class RefreshEdgeJob < ApplicationJob
  queue_as :ingest

  # Sorts above every numbered release in pickers and lists.
  EDGE_ORD = 9_999_999

  # The modern framework path set — mirrors script/backfill, which
  # existence-checks because old tags lack some of these; main always
  # has them all.
  SOURCE_DIRS = %w[
    activesupport/lib activerecord/lib activemodel/lib actionpack/lib
    actionview/lib actionview/app actionmailer/lib activejob/lib
    actioncable/lib actioncable/app activestorage/lib activestorage/app
    actionmailbox/lib actionmailbox/app actiontext/lib actiontext/app
    railties/lib
  ].freeze

  def perform
    sha = fetch_main_sha
    if sha == current_edge_sha
      Rails.logger.info "[edge] main unchanged at #{sha}, skipping"
      return
    end

    IngestPackageVersionJob.perform_later(
      source_slug: "rails",
      channel: "edge",
      git_ref: "main",
      git_sha: sha,
      ord: EDGE_ORD,
      source_dirs: SOURCE_DIRS
    )
  end

  private

  def repo_root
    ENV.fetch("INGEST_REPO_ROOT_RAILS") { Rails.root.join("tmp/repos/rails").to_s }
  end

  def fetch_main_sha
    git("fetch", "--quiet", "origin", "main")
    git("rev-parse", "--short=10", "origin/main").strip
  end

  def current_edge_sha
    Source.find_by(slug: "rails")&.package_versions&.find_by(channel: "edge")&.git_sha
  end

  def git(*args)
    stdout, stderr, status = Open3.capture3("git", "-C", repo_root, *args)
    return stdout if status.success?

    raise "git #{args.first} failed (exit #{status.exitstatus}): #{stderr.strip}"
  end
end
