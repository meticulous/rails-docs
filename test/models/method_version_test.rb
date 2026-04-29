require "test_helper"

class MethodVersionTest < ActiveSupport::TestCase
  test "persists with valid attributes" do
    method_version = MethodVersion.new(
      entity_version: entity_versions(:ar_persistence_save_v8_1_3),
      yields: "value"
    )
    assert method_version.save
    assert_not method_version.ghost?
  end

  test "one entity_version maps to at most one method_version" do
    MethodVersion.create!(entity_version: entity_versions(:ar_persistence_save_v8_1_3))
    duplicate = MethodVersion.new(entity_version: entity_versions(:ar_persistence_save_v8_1_3))
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:entity_version_id, :taken)
  end

  test "aliased points to another entity_identity" do
    other = sources(:rails).entity_identities.create!(
      fqn: "ActiveRecord::Persistence#store",
      kind: "method",
      name: "store",
      scope: "instance"
    )
    method_version = MethodVersion.create!(
      entity_version: entity_versions(:ar_persistence_save_v8_1_3),
      aliased: other
    )
    assert_equal other, method_version.aliased
  end
end
