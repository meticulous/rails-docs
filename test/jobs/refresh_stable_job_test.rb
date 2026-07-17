require "test_helper"

class RefreshStableJobTest < ActiveJob::TestCase
  # Fixtures give rails channels 8.1.3, 8.0.4, and edge.

  test "enqueues the newest missing patch of a tracked series" do
    job = stubbed_job(tags: %w[v8.0.4 v8.1.3 v8.1.4], shas: { "v8.1.4" => "abc123def4" })

    assert_enqueued_with(
      job: IngestPackageVersionJob,
      args: [ {
        source_slug: "rails",
        channel: "8.1.4",
        git_ref: "v8.1.4",
        git_sha: "abc123def4",
        ord: 8_001_004,
        source_dirs: RefreshEdgeJob::SOURCE_DIRS
      } ]
    ) do
      job.perform
    end
  end

  test "skips channels we already have and ignores rc and beta tags" do
    job = stubbed_job(tags: %w[v8.0.4 v8.1.3 v8.2.0.beta1 v8.2.0.rc1])

    assert_no_enqueued_jobs only: IngestPackageVersionJob do
      job.perform
    end
  end

  test "picks up a new minor series and a four-segment security release" do
    job = stubbed_job(
      tags: %w[v8.0.4 v8.0.4.1 v8.1.3 v8.2.0],
      shas: { "v8.0.4.1" => "sec0000001", "v8.2.0" => "new0000001" }
    )

    assert_enqueued_jobs 2, only: IngestPackageVersionJob do
      job.perform
    end
  end

  test "leaves series older than the backfill floor alone" do
    # Oldest tracked series in fixtures is 8.0 — a 7.2 release must not ingest.
    job = stubbed_job(tags: %w[v7.2.9 v8.0.4 v8.1.3])

    assert_no_enqueued_jobs only: IngestPackageVersionJob do
      job.perform
    end
  end

  test "four-segment ords drop the tiny segment, matching the backfill scheme" do
    assert_equal 6_001_007, RefreshStableJob.new.send(:ord_for, "v6.1.7.10")
    assert_equal 8_001_004, RefreshStableJob.new.send(:ord_for, "v8.1.4")
  end

  private

  # Stubs the two git touchpoints; everything else runs for real.
  def stubbed_job(tags:, shas: {})
    job = RefreshStableJob.new
    job.define_singleton_method(:git) do |*args|
      case args.first
      when "fetch" then ""
      when "tag" then tags.join("\n")
      when "rev-parse" then shas.fetch(args.last)
      end
    end
    job
  end
end
