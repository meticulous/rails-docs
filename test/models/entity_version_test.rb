require "test_helper"

class EntityVersionTest < ActiveSupport::TestCase
  test "persists with valid attributes" do
    version = EntityVersion.new(
      entity_identity: entity_identities(:ar_persistence_save),
      package_version: package_versions(:edge)
    )
    assert version.save
    assert_equal "public", version.visibility
  end

  test "visibility must be a known value" do
    version = EntityVersion.new(
      entity_identity: entity_identities(:ar_persistence_save),
      package_version: package_versions(:edge),
      visibility: "secret"
    )
    assert_not version.valid?
    assert version.errors.of_kind?(:visibility, :inclusion)
  end

  test "one identity cannot have two versions in the same package" do
    fixture = entity_versions(:ar_persistence_save_v8_1_3)
    duplicate = EntityVersion.new(
      entity_identity: fixture.entity_identity,
      package_version: fixture.package_version
    )
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:entity_identity_id, :taken)
  end

  test "delegates name, fqn, kind, scope to entity_identity" do
    version = entity_versions(:ar_persistence_save_v8_1_3)
    identity = version.entity_identity
    assert_equal identity.name, version.name
    assert_equal identity.fqn, version.fqn
    assert_equal identity.kind, version.kind
    assert_equal identity.scope, version.scope
  end
end
