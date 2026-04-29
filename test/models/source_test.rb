require "test_helper"

class SourceTest < ActiveSupport::TestCase
  test "persists with valid attributes" do
    source = Source.new(slug: "fork", display_name: "Fork", github_repo: "fork/rails")
    assert source.save
    assert_equal "main", source.default_branch
  end

  test "slug must be unique" do
    duplicate = Source.new(
      slug: sources(:rails).slug,
      display_name: "Other",
      github_repo: "other/other"
    )
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:slug, :taken)
  end

  test "requires slug, display_name, github_repo" do
    source = Source.new
    assert_not source.valid?
    assert source.errors.of_kind?(:slug, :blank)
    assert source.errors.of_kind?(:display_name, :blank)
    assert source.errors.of_kind?(:github_repo, :blank)
  end
end
