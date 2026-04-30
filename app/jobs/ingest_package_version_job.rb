# Runs the per-tag ingest pipeline:
#   1. Ensures a worktree of the rails repo at the given git_ref exists
#   2. Invokes the rails_docs_ingester gem (subprocess, vendored gemfile)
#   3. Loads the produced JSONL via Loader
#
# Designed to run under Solid Queue in production. The shell-out matches
# what script/backfill does manually so behavior is consistent.
class IngestPackageVersionJob < ApplicationJob
  queue_as :ingest

  # source_slug:  "rails", "turbo-rails", etc.
  # channel:      "8.1.3", "edge"
  # git_ref:      "v8.1.3" (the tag/ref to check out)
  # git_sha:      "abcdef0..." (full or short)
  # ord:          monotonic sort key (8001003 for 8.1.3, etc.)
  # source_dirs:  array of paths under the worktree to feed RDoc
  def perform(source_slug:, channel:, git_ref:, git_sha:, ord:, source_dirs:)
    Rails.logger.info "[ingest] starting #{source_slug} #{channel} (#{git_ref})"

    worktree = ensure_worktree(source_slug, git_ref)
    jsonl = run_ingester(
      source_slug: source_slug,
      channel: channel,
      git_ref: git_ref,
      git_sha: git_sha,
      ord: ord,
      worktree: worktree,
      source_dirs: source_dirs
    )
    run_loader(jsonl)
    Rails.logger.info "[ingest] finished #{source_slug} #{channel}"
  end

  private

  def ensure_worktree(source_slug, git_ref)
    repo_root = ENV.fetch("INGEST_REPO_ROOT_#{source_slug.tr('-', '_').upcase}") {
      Rails.root.join("tmp/repos/#{source_slug}").to_s
    }
    worktree = "#{repo_root}-#{git_ref.tr('/', '_')}"

    # Production: pre-cloned source repos live in a known dir; we just add
    # a worktree at the requested ref. If the bare repo isn't there yet
    # the deploy needs to clone it once; we don't do `git clone` here to
    # avoid network-fetch surprises during a queued job.
    unless File.directory?(worktree)
      run_git("worktree", "add", worktree, git_ref, cwd: repo_root)
    end
    worktree
  end

  def run_ingester(source_slug:, channel:, git_ref:, git_sha:, ord:, worktree:, source_dirs:)
    output_dir = ENV.fetch("INGEST_OUTPUT_DIR", Rails.root.join("tmp/ingest_output").to_s)
    FileUtils.mkdir_p(output_dir)
    jsonl = File.join(output_dir, "#{source_slug}-#{channel}.jsonl")

    args = [
      ENV.fetch("INGESTER_BIN", File.expand_path("~/Development/Rails/rails_docs_ingester/exe/rails_docs_ingester")),
      "--output", jsonl,
      "--source-root", worktree,
      "--channel", channel,
      "--git-ref", git_ref,
      "--git-sha", git_sha,
      "--ord", ord.to_s,
      "--source-slug", source_slug,
      "--quiet",
      *source_dirs
    ]
    success = system(*args)
    raise "ingester failed for #{source_slug} #{channel}" unless success
    jsonl
  end

  def run_loader(jsonl_path)
    File.open(jsonl_path, "r:UTF-8") { |io| Loader.new(io).import! }
  end

  def run_git(*args, cwd:)
    success = system("git", "-C", cwd, *args)
    raise "git #{args.first} failed in #{cwd}" unless success
  end
end
