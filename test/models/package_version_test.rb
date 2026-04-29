require "test_helper"

class PackageVersionTest < ActiveSupport::TestCase
  test "persists with valid attributes" do
    version = sources(:rails).package_versions.new(
      channel: "9.0.0",
      git_ref: "v9.0.0",
      git_sha: "9000000",
      ord: 9000000
    )
    assert version.save
    assert version.pending?
  end

  test "channel is unique per source" do
    duplicate = sources(:rails).package_versions.new(
      channel: package_versions(:v8_1_3).channel,
      git_ref: "v8.1.3",
      git_sha: "abc",
      ord: 1
    )
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:channel, :taken)
  end

  test "ingest_status enum exposes predicates and bang setters" do
    version = package_versions(:v8_1_3)
    assert version.ok?
    version.failed!
    assert version.reload.failed?
  end
end
