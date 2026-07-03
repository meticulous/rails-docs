require "test_helper"

class EntityIdentityTest < ActiveSupport::TestCase
  test "persists a class identity" do
    identity = sources(:rails).entity_identities.new(
      fqn: "ActionController::Base",
      kind: "class",
      name: "Base",
      parent_fqn: "ActionController"
    )
    assert identity.save
  end

  test "persists a method identity with scope" do
    identity = sources(:rails).entity_identities.new(
      fqn: "ActionController::Base#render",
      kind: "method",
      name: "render",
      scope: "instance",
      parent_fqn: "ActionController::Base"
    )
    assert identity.save
  end

  test "kind must be a known value" do
    identity = sources(:rails).entity_identities.new(fqn: "Foo", kind: "bogus", name: "Foo")
    assert_not identity.valid?
    assert identity.errors.of_kind?(:kind, :inclusion)
  end

  test "scope when set must be a known value" do
    identity = sources(:rails).entity_identities.new(
      fqn: "Foo#bar", kind: "method", name: "bar", scope: "global"
    )
    assert_not identity.valid?
    assert identity.errors.of_kind?(:scope, :inclusion)
  end

  test "instance and singleton methods with same fqn coexist" do
    sources(:rails).entity_identities.create!(
      fqn: "Bar.baz", kind: "method", name: "baz", scope: "singleton"
    )
    instance = sources(:rails).entity_identities.new(
      fqn: "Bar.baz", kind: "method", name: "baz", scope: "instance"
    )
    assert instance.valid?
  end

  test "duplicate fqn within same source/kind/scope is rejected" do
    duplicate = sources(:rails).entity_identities.new(
      fqn: entity_identities(:ar_persistence_save).fqn,
      kind: "method",
      name: "save",
      scope: "instance"
    )
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:fqn, :taken)
  end

  test "first_seen_version is back-referenced from package_version" do
    identity = entity_identities(:ar_persistence_save)
    identity.update!(first_seen_version: package_versions(:v8_1_3))
    assert_equal package_versions(:v8_1_3), identity.reload.first_seen_version
    assert_includes package_versions(:v8_1_3).first_seen_identities, identity
  end

  test "last_seen_version is back-referenced from package_version" do
    identity = entity_identities(:ar_persistence_save)
    identity.update!(last_seen_version: package_versions(:edge))
    assert_equal package_versions(:edge), identity.reload.last_seen_version
    assert_includes package_versions(:edge).last_seen_identities, identity
  end

  test "content_digest_by_version returns one digest per package_version" do
    identity = entity_identities(:ar_persistence_save)
    digests = identity.content_digest_by_version

    assert_includes digests.keys, package_versions(:v8_1_3).id
    assert_includes digests.keys, package_versions(:v8_0_4).id
    # v8.0.4 fixture is byte-identical content to v8.1.3, so same digest.
    assert_equal digests[package_versions(:v8_1_3).id], digests[package_versions(:v8_0_4).id]
  end

  test "content_digest_by_version distinguishes differing documentation" do
    identity = entity_identities(:ar_persistence_save)
    EntityVersion.create!(
      entity_identity: identity,
      package_version: package_versions(:edge),
      doc_markdown: "Saves the record, now with more magic."
    )

    digests = identity.content_digest_by_version
    assert_not_equal digests[package_versions(:v8_1_3).id], digests[package_versions(:edge).id]
  end

  test "content_digest_by_version distinguishes differing source_code" do
    identity = entity_identities(:ar_persistence_save)
    # Same doc_markdown/signature_text as v8.1.3, different source_code —
    # the diff page renders source diffs, so this must digest "changed".
    EntityVersion.create!(
      entity_identity: identity,
      package_version: package_versions(:edge),
      doc_markdown: "Saves the record.",
      source_code: "def save; super; end"
    )

    digests = identity.content_digest_by_version
    assert_not_equal digests[package_versions(:v8_1_3).id], digests[package_versions(:edge).id]
  end

  test "content_digest_by_version ignores fields the diff page does not render" do
    identity = entity_identities(:ar_persistence_save)
    # Same doc/signature/source as v8.1.3; call_seq and deprecated differ.
    # Neither is rendered by the diff page, so this must digest "same" or
    # the changed/same picker tags would promise a diff the page can't
    # show.
    EntityVersion.create!(
      entity_identity: identity,
      package_version: package_versions(:edge),
      doc_markdown: "Saves the record.",
      call_seq: "save -> true or false",
      deprecated: true
    )

    digests = identity.content_digest_by_version
    assert_equal digests[package_versions(:v8_1_3).id], digests[package_versions(:edge).id]
  end

  test "changed_version_ids excludes the identical version and the baseline itself" do
    identity = entity_identities(:ar_persistence_save)
    EntityVersion.create!(
      entity_identity: identity,
      package_version: package_versions(:edge),
      doc_markdown: "Saves the model with extra magic.", # differs from v8.1.3
      signature_text: "(**options)"
    )

    changed = identity.changed_version_ids(relative_to: package_versions(:v8_1_3))

    assert_includes changed, package_versions(:edge).id       # content differs -> changed
    assert_not_includes changed, package_versions(:v8_0_4).id # identical content -> same
    assert_not_includes changed, package_versions(:v8_1_3).id # baseline is never "changed"
  end
end
