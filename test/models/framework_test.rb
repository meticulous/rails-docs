require "test_helper"

class FrameworkTest < ActiveSupport::TestCase
  test "persists with valid attributes" do
    framework = sources(:rails).frameworks.new(slug: "actioncable", display_name: "Action Cable")
    assert framework.save
  end

  test "slug is unique per source" do
    duplicate = sources(:rails).frameworks.new(
      slug: frameworks(:activerecord).slug,
      display_name: "AR"
    )
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:slug, :taken)
  end
end
