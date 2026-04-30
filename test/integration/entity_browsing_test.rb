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

  test "home page surfaces frameworks for the current stable" do
    get root_path
    assert_response :success
    assert_select ".home__frameworks h2", "Frameworks"
    # ActiveRecord top module isn't ingested in fixtures, so the card title
    # falls back to plain display_name text rather than an entity link.
    assert_select ".framework-grid .framework-card h3", text: "Active Record"
    assert_select ".framework-grid .framework-card", minimum: 1
  end

  test "renders an Active Record class page" do
    get entity_path(version: "v8.1.3", path: "active_record/base")
    assert_response :success
    assert_select "h1", text: /Base/
    assert_select ".breadcrumbs [aria-current='page']", "Base"
    assert_select ".breadcrumbs a", text: "ActiveRecord"
    assert_select ".entity__version", "Ruby on Rails 8.1.3"
    assert_select ".entity__inherited-methods h2", "Methods (inherited)"
    assert_select ".method-group summary a", text: "ActiveRecord::Persistence"
  end

  test "renders an Active Record module page" do
    get entity_path(version: "v8.1.3", path: "active_record/persistence")
    assert_response :success
    assert_select "h1", text: /Persistence/
    assert_select ".entity__kind", "module"
  end

  test "renders a per-method instance page" do
    get entity_path(version: "v8.1.3", path: "active_record/persistence/save")
    assert_response :success
    assert_select "h1 code", text: /save/
    assert_select ".entity__kind", "instance method"
  end

  test "renders a singleton method via .class suffix" do
    singleton = sources(:rails).entity_identities.create!(
      fqn: "ActiveRecord::Persistence.create",
      kind: "method",
      name: "create",
      scope: "singleton",
      parent_fqn: "ActiveRecord::Persistence"
    )
    EntityVersion.create!(entity_identity: singleton, package_version: package_versions(:v8_1_3))

    get entity_path(version: "v8.1.3", path: "active_record/persistence/create.class")
    assert_response :success
    assert_select ".entity__kind", "class method"
    assert_select "h1 code", text: /self\.create/
  end

  test "renders a constant page" do
    constant = sources(:rails).entity_identities.create!(
      fqn: "ActiveRecord::Base::DEFAULT_PER_PAGE",
      kind: "constant",
      name: "DEFAULT_PER_PAGE",
      parent_fqn: "ActiveRecord::Base"
    )
    EntityVersion.create!(entity_identity: constant, package_version: package_versions(:v8_1_3))
    ConstantVersion.create!(entity_version: constant.entity_versions.first, value_expr: "25")

    get entity_path(version: "v8.1.3", path: "active_record/base/DEFAULT_PER_PAGE")
    assert_response :success
    assert_select "h1", text: /DEFAULT_PER_PAGE/
    assert_select ".entity__kind", "constant"
  end

  test "renders an attribute page" do
    get entity_path(version: "v8.1.3", path: "foo/name")
    assert_response :success
    assert_select "h1", text: /name/
    assert_select ".entity__kind", "attribute"
  end

  test "operator method slug round-trips through the URL" do
    bracket = sources(:rails).entity_identities.create!(
      fqn: "ActiveRecord::AttributeMethods#[]",
      kind: "method",
      name: "[]",
      scope: "instance",
      parent_fqn: "ActiveRecord::AttributeMethods"
    )
    EntityVersion.create!(entity_identity: bracket, package_version: package_versions(:v8_1_3))

    get entity_path(version: "v8.1.3", path: "active_record/attribute_methods/bracket")
    assert_response :success
    assert_select "h1 code", text: /\[\]/
  end

  test "404 for unknown entities" do
    get entity_path(version: "v8.1.3", path: "does_not_exist")
    assert_response :not_found
  end

  test "404 for an unknown version" do
    get entity_path(version: "v0.0.0", path: "active_record/base")
    assert_response :not_found
  end
end
