require "test_helper"

class FeedsTest < ActionDispatch::IntegrationTest
  setup do
    package_versions(:v8_1_3).update!(ingest_status: "ok", ingested_at: Time.current)
  end

  test "framework feed lists entities first seen in the current stable version" do
    entity_identities(:ar_base).update!(first_seen_version: package_versions(:v8_1_3))

    get framework_feed_url(framework_slug: "activerecord")
    assert_response :success
    assert_equal "application/atom+xml", response.media_type

    assert_includes response.body, "What's new in Active Record 8.1.3"
    assert_includes response.body, "Added: ActiveRecord::Base"
  end

  test "source feed lists entities for a non-rails source" do
    turbo_rails = sources(:turbo_rails)
    package_versions(:turbo_rails_v2_14_1).update!(ingest_status: "ok", ingested_at: Time.current)

    get source_feed_url(source_slug: turbo_rails.slug)
    assert_response :success
    assert_equal "application/atom+xml", response.media_type
    assert_includes response.body, "What's new in #{turbo_rails.display_name} 2.14.1"
  end

  test "framework feed 404s when the framework has no current stable version" do
    package_versions(:v8_1_3).update!(ingest_status: "pending", ingested_at: nil)
    get framework_feed_url(framework_slug: "activerecord")
    assert_response :not_found
  end

  test "framework feed 404s for an unknown framework slug" do
    get framework_feed_url(framework_slug: "does-not-exist")
    assert_response :not_found
  end
end
