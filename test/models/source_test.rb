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

  test "description returns the one-line blurb for known ecosystem gems" do
    assert_equal Source::DESCRIPTIONS["turbo-rails"], sources(:turbo_rails).description
  end

  test "description returns nil for sources without a blurb" do
    assert_nil sources(:rails).description
    assert_nil Source.new(slug: "some_future_gem").description
  end

  test "current_stable never returns edge, even when edge is ingested with the top ord" do
    package_versions(:v8_1_3).update!(ingested_at: Time.current)
    package_versions(:edge).update!(ingested_at: Time.current) # ord 9999999, above every release

    assert_equal package_versions(:v8_1_3), sources(:rails).current_stable
  end
end
