require "test_helper"

class MethodParamTest < ActiveSupport::TestCase
  test "persists a required positional param" do
    param = MethodParam.new(
      entity_version: entity_versions(:ar_persistence_save_v8_1_3),
      position: 0,
      name: "x",
      kind: "req"
    )
    assert param.save
  end

  test "kind must be a known value" do
    param = MethodParam.new(
      entity_version: entity_versions(:ar_persistence_save_v8_1_3),
      position: 0,
      name: "x",
      kind: "bogus"
    )
    assert_not param.valid?
    assert param.errors.of_kind?(:kind, :inclusion)
  end

  test "position is unique within an entity_version" do
    MethodParam.create!(
      entity_version: entity_versions(:ar_persistence_save_v8_1_3),
      position: 0, name: "x", kind: "req"
    )
    duplicate = MethodParam.new(
      entity_version: entity_versions(:ar_persistence_save_v8_1_3),
      position: 0, name: "y", kind: "req"
    )
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:position, :taken)
  end

  test "position must be non-negative" do
    param = MethodParam.new(
      entity_version: entity_versions(:ar_persistence_save_v8_1_3),
      position: -1, name: "x", kind: "req"
    )
    assert_not param.valid?
    assert param.errors.of_kind?(:position, :greater_than_or_equal_to)
  end
end
