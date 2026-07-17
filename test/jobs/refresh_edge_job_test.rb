require "test_helper"

class RefreshEdgeJobTest < ActiveJob::TestCase
  test "enqueues an edge ingest when main's tip has moved" do
    job = RefreshEdgeJob.new
    job.define_singleton_method(:fetch_main_sha) { "aabbccddee" }

    assert_enqueued_with(
      job: IngestPackageVersionJob,
      args: [ {
        source_slug: "rails",
        channel: "edge",
        git_ref: "main",
        git_sha: "aabbccddee",
        ord: RefreshEdgeJob::EDGE_ORD,
        source_dirs: RefreshEdgeJob::SOURCE_DIRS
      } ]
    ) do
      job.perform
    end
  end

  test "skips when edge is already at main's sha" do
    package_versions(:edge).update!(git_sha: "aabbccddee")

    job = RefreshEdgeJob.new
    job.define_singleton_method(:fetch_main_sha) { "aabbccddee" }

    assert_no_enqueued_jobs only: IngestPackageVersionJob do
      job.perform
    end
  end

  test "first-ever run enqueues even with no edge row" do
    package_versions(:edge).destroy!

    job = RefreshEdgeJob.new
    job.define_singleton_method(:fetch_main_sha) { "aabbccddee" }

    assert_enqueued_jobs 1, only: IngestPackageVersionJob do
      job.perform
    end
  end
end
