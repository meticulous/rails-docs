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

  # ---- prune_superseded_patches! ----

  test "prune removes older patches of the same series and their rows" do
    v8_1_2 = older_patch("8.1.2")
    only_in_old = sources(:rails).entity_identities.create!(fqn: "GoneInNew", kind: "class", name: "GoneInNew")
    EntityVersion.create!(entity_identity: only_in_old, package_version: v8_1_2)
    shared = entity_identities(:ar_persistence_save)
    old_ev = EntityVersion.create!(entity_identity: shared, package_version: v8_1_2)
    shared.update!(first_seen_version_id: v8_1_2.id, last_seen_version_id: package_versions(:v8_1_3).id)

    removed = package_versions(:v8_1_3).prune_superseded_patches!

    assert_equal [ v8_1_2 ], removed
    assert_not PackageVersion.exists?(v8_1_2.id)
    assert_not EntityVersion.exists?(old_ev.id)
    # Identity that only existed in the pruned version goes with it.
    assert_not EntityIdentity.exists?(only_in_old.id)
    # Shared identity survives with its pointers repaired to what remains
    # (the fixture also lives in v8.0.4, which is now its oldest version).
    shared.reload
    assert_equal package_versions(:v8_0_4), shared.first_seen_version
    assert_equal package_versions(:v8_1_3), shared.last_seen_version
  end

  test "prune keeps version-less identities that are still referenced" do
    older_patch("8.1.2")
    # A superclass that never had docs of its own: no entity_versions,
    # but referenced by a surviving version's class_version row.
    ghost_super = sources(:rails).entity_identities.create!(fqn: "GhostBase", kind: "class", name: "GhostBase")
    ClassVersion.create!(
      entity_version: entity_versions(:ar_persistence_save_v8_1_3),
      superclass_identity: ghost_super
    )

    package_versions(:v8_1_3).prune_superseded_patches!

    assert EntityIdentity.exists?(ghost_super.id), "referenced-only identities must survive the orphan sweep"
  end

  test "prune leaves other series and edge alone" do
    package_versions(:v8_1_3).prune_superseded_patches!

    assert PackageVersion.exists?(package_versions(:v8_0_4).id), "different series must survive"
    assert PackageVersion.exists?(package_versions(:edge).id), "edge must survive"
  end

  test "a four-segment security release supersedes its base patch but not newer ones" do
    v8_1_2 = older_patch("8.1.2")
    v8_1_2_1 = older_patch("8.1.2.1")

    removed = v8_1_2_1.prune_superseded_patches!

    assert_equal [ v8_1_2 ], removed
    assert PackageVersion.exists?(package_versions(:v8_1_3).id), "8.1.2.1 must never prune the newer 8.1.3"
  end

  test "edge never prunes anything" do
    v8_1_2 = older_patch("8.1.2")
    assert_equal [], package_versions(:edge).prune_superseded_patches!
    assert PackageVersion.exists?(v8_1_2.id)
  end

  private

  def older_patch(channel)
    sources(:rails).package_versions.create!(
      channel: channel, release_series: "8.1", git_ref: "v#{channel}",
      git_sha: "sha#{channel.delete('.')}", ord: 8_001_002,
      ingest_status: "ok", ingested_at: 1.week.ago
    )
  end
end
