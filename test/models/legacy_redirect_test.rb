require "test_helper"

class LegacyRedirectTest < ActiveSupport::TestCase
  test "persists with valid attributes" do
    redirect = LegacyRedirect.new(
      package_version: package_versions(:v8_1_3),
      old_path: "/classes/Foo.html#method-i-bar",
      entity_version: entity_versions(:ar_persistence_save_v8_1_3)
    )
    assert redirect.save
  end

  test "old_path is unique per package_version" do
    LegacyRedirect.create!(
      package_version: package_versions(:v8_1_3),
      old_path: "/classes/Foo.html#method-i-bar",
      entity_version: entity_versions(:ar_persistence_save_v8_1_3)
    )
    duplicate = LegacyRedirect.new(
      package_version: package_versions(:v8_1_3),
      old_path: "/classes/Foo.html#method-i-bar",
      entity_version: entity_versions(:ar_persistence_save_v8_1_3)
    )
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:old_path, :taken)
  end
end
