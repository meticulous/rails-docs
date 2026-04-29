require "test_helper"

class ClassVersionTest < ActiveSupport::TestCase
  test "persists with a superclass identity" do
    class_version = ClassVersion.new(
      entity_version: entity_versions(:ar_base_v8_1_3),
      superclass_identity: entity_identities(:ar_persistence)
    )
    assert class_version.save
    assert_equal entity_identities(:ar_persistence), class_version.superclass_identity
  end

  test "one entity_version maps to at most one class_version" do
    ClassVersion.create!(entity_version: entity_versions(:ar_base_v8_1_3))
    duplicate = ClassVersion.new(entity_version: entity_versions(:ar_base_v8_1_3))
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:entity_version_id, :taken)
  end
end
