require "test_helper"

class EntityBrowsingTest < ActionDispatch::IntegrationTest
  setup do
    package_versions(:v8_1_3).update!(ingest_status: "ok", ingested_at: Time.current)
    InheritanceEdge.create!(
      package_version: package_versions(:v8_1_3),
      child_identity: entity_identities(:ar_base),
      ancestor_identity: entity_identities(:ar_persistence),
      relation: "include",
      position: 0
    )
    InheritanceClosure.create!(
      package_version: package_versions(:v8_1_3),
      descendant_identity: entity_identities(:ar_base),
      ancestor_identity: entity_identities(:ar_persistence),
      depth: 1,
      via_relation: "include"
    )
  end

  test "home page lists ingested versions" do
    get root_path
    assert_response :success
    assert_select "h1", "Ruby on Rails API"
    assert_select ".version-list a", text: "v8.1.3"
  end

  test "renders an Active Record class page" do
    get entity_path(version: "v8.1.3", path: "active_record/base")
    assert_response :success
    assert_select "h1", text: /Base/
    assert_select ".entity__breadcrumb", "ActiveRecord::Base"
    assert_select ".entity__version", "Ruby on Rails 8.1.3"
    assert_select ".entity__inherited-methods h2", "Methods (inherited)"
    assert_select ".method-group summary code", "ActiveRecord::Persistence"
  end

  test "renders an Active Record module page" do
    get entity_path(version: "v8.1.3", path: "active_record/persistence")
    assert_response :success
    assert_select "h1", text: /Persistence/
    assert_select ".entity__kind", "module"
  end

  test "404 for unknown entities" do
    get entity_path(version: "v8.1.3", path: "does_not_exist")
    assert_response :not_found
  end
end
