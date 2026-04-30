require "test_helper"

class LegacyRedirectsTest < ActionDispatch::IntegrationTest
  setup do
    package_versions(:v8_1_3).update!(ingest_status: "ok", ingested_at: Time.current)
  end

  test "/classes/ActiveRecord/Persistence.html redirects to current stable" do
    get "/classes/ActiveRecord/Persistence.html"
    assert_response :moved_permanently
    assert_redirected_to entity_path(version: "v8.1.3", path: "active_record/persistence")
  end

  test "/classes/Unknown.html returns 404" do
    get "/classes/Unknown.html"
    assert_response :not_found
  end

  test "/files/* redirects to home" do
    get "/files/some/file.html"
    assert_response :moved_permanently
    assert_redirected_to root_path
  end

  test "/_legacy_method redirects to per-method page" do
    get "/_legacy_method", params: {
      parent_path: "/v8.1.3/active_record/persistence",
      name: "save",
      scope: "instance"
    }
    assert_response :moved_permanently
    assert_redirected_to "/v8.1.3/active_record/persistence/save"
  end

  test "/_legacy_method handles operator method names" do
    get "/_legacy_method", params: {
      parent_path: "/v8.1.3/active_record/attribute_methods",
      name: "[]",
      scope: "instance"
    }
    assert_response :moved_permanently
    assert_redirected_to "/v8.1.3/active_record/attribute_methods/bracket"
  end

  test "/_legacy_method appends .class for singleton methods" do
    get "/_legacy_method", params: {
      parent_path: "/v8.1.3/active_record/persistence",
      name: "create",
      scope: "singleton"
    }
    assert_response :moved_permanently
    assert_redirected_to "/v8.1.3/active_record/persistence/create.class"
  end
end
