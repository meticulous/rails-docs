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
end
