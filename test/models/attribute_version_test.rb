require "test_helper"

class AttributeVersionTest < ActiveSupport::TestCase
  test "persists with rw RW" do
    attr_version = AttributeVersion.new(entity_version: entity_versions(:foo_name_v8_1_3), rw: "RW")
    assert attr_version.save
  end

  test "rw must be one of R, W, RW" do
    attr_version = AttributeVersion.new(entity_version: entity_versions(:foo_name_v8_1_3), rw: "X")
    assert_not attr_version.valid?
    assert attr_version.errors.of_kind?(:rw, :inclusion)
  end

  test "one entity_version maps to at most one attribute_version" do
    AttributeVersion.create!(entity_version: entity_versions(:foo_name_v8_1_3), rw: "RW")
    duplicate = AttributeVersion.new(entity_version: entity_versions(:foo_name_v8_1_3), rw: "RW")
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:entity_version_id, :taken)
  end
end
