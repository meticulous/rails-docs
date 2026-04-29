require "test_helper"

class ConstantVersionTest < ActiveSupport::TestCase
  test "persists with a value expression" do
    constant_version = ConstantVersion.new(
      entity_version: entity_versions(:foo_bar_v8_1_3),
      value_expr: "42"
    )
    assert constant_version.save
  end

  test "one entity_version maps to at most one constant_version" do
    ConstantVersion.create!(entity_version: entity_versions(:foo_bar_v8_1_3))
    duplicate = ConstantVersion.new(entity_version: entity_versions(:foo_bar_v8_1_3))
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:entity_version_id, :taken)
  end
end
