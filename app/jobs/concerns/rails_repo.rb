require "open3"

# Shared git access to the pre-cloned rails repo the nightly refresh
# jobs read from (INGEST_REPO_ROOT_RAILS, same clone the ingest
# pipeline worktrees against).
module RailsRepo
  private

  def repo_root
    ENV.fetch("INGEST_REPO_ROOT_RAILS") { Rails.root.join("tmp/repos/rails").to_s }
  end

  # Always fetch from canonical rails/rails by URL, never from whatever
  # the clone's origin happens to be — a clone made from a fork would
  # silently stop seeing new releases (a fork's tags lag until someone
  # syncs them).
  def upstream_url
    ENV.fetch("INGEST_UPSTREAM_RAILS", "https://github.com/rails/rails")
  end

  def git(*args)
    stdout, stderr, status = Open3.capture3("git", "-C", repo_root, *args)
    return stdout if status.success?

    raise "git #{args.first} failed (exit #{status.exitstatus}): #{stderr.strip}"
  end
end
