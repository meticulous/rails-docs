require "test_helper"

class InheritanceEdgeTest < ActiveSupport::TestCase
  test "persists an include edge" do
    edge = InheritanceEdge.new(
      package_version: package_versions(:v8_1_3),
      child_identity: entity_identities(:ar_base),
      ancestor_identity: entity_identities(:ar_persistence),
      relation: "include",
      position: 0
    )
    assert edge.save
  end

  test "relation must be a known value" do
    edge = InheritanceEdge.new(
      package_version: package_versions(:v8_1_3),
      child_identity: entity_identities(:ar_base),
      ancestor_identity: entity_identities(:ar_persistence),
      relation: "delegates_to"
    )
    assert_not edge.valid?
    assert edge.errors.of_kind?(:relation, :inclusion)
  end

  test "duplicate edge in same version is rejected" do
    InheritanceEdge.create!(
      package_version: package_versions(:v8_1_3),
      child_identity: entity_identities(:ar_base),
      ancestor_identity: entity_identities(:ar_persistence),
      relation: "include",
      position: 0
    )
    duplicate = InheritanceEdge.new(
      package_version: package_versions(:v8_1_3),
      child_identity: entity_identities(:ar_base),
      ancestor_identity: entity_identities(:ar_persistence),
      relation: "include"
    )
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:child_identity_id, :taken)
  end
end
