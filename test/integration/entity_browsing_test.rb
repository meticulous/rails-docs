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

  test "left module-nav renders on every page, grouped by framework" do
    get entity_path(version: "v8.1.3", path: "active_record/persistence")
    assert_response :success
    # The persistent left nav: filter input + at least one framework group
    assert_select "aside.module-nav .module-nav__filter"
    assert_select "aside.module-nav details.module-nav__group", minimum: 1
    # Active-framework slug is wired so the controller can pre-expand
    assert_select "aside.module-nav[data-module-nav-active-framework-value='activerecord']"
    # The toggle button persists the user's preference
    assert_select "button.module-nav-toggle"
  end

  test "module-nav renders a namespace tree with leaf-only labels" do
    # Give ActiveRecord a nested grandchild so a parent node gets a toggle.
    enc = sources(:rails).entity_identities.create!(
      fqn: "ActiveRecord::Encryption", kind: "module", name: "Encryption",
      parent_fqn: "ActiveRecord", framework: frameworks(:activerecord)
    )
    EntityVersion.create!(entity_identity: enc, package_version: package_versions(:v8_1_3))
    cipher = sources(:rails).entity_identities.create!(
      fqn: "ActiveRecord::Encryption::Cipher", kind: "class", name: "Cipher",
      parent_fqn: "ActiveRecord::Encryption", framework: frameworks(:activerecord)
    )
    EntityVersion.create!(entity_identity: cipher, package_version: package_versions(:v8_1_3))

    get entity_path(version: "v8.1.3", path: "active_record/persistence")
    assert_response :success

    # Tree container, nodes keyed by lowercased FQN
    assert_select "ul.module-nav__tree"
    assert_select "li.module-nav__node[data-fqn='activerecord::persistence']"
    assert_select "li.module-nav__node[data-fqn='activerecord::encryption::cipher']"

    # Leaf label shows the last segment only, not the full FQN
    assert_select "li.module-nav__node[data-fqn='activerecord::encryption::cipher'] .module-nav__link",
                  text: "Cipher"

    # A parent node carries a toggle button; its children start hidden
    assert_select "li.module-nav__node[data-fqn='activerecord::encryption'] > .module-nav__row > button.module-nav__toggle"
    assert_select "li.module-nav__node[data-fqn='activerecord::encryption'] > ul.module-nav__children[hidden]"
  end

  test "module-nav data attrs expose the active FQN and its upstream trail" do
    # Method page → active steps up to the parent class/module
    get entity_path(version: "v8.1.3", path: "active_record/persistence/save")
    assert_response :success
    assert_select "aside.module-nav[data-module-nav-active-fqn-value='ActiveRecord::Persistence']"
    assert_select "aside.module-nav[data-module-nav-upstream-fqns-value=?]", "[\"ActiveRecord\"]"
  end

  test "module-nav has no active fqn on home / search / ecosystem" do
    get root_path
    assert_select "aside.module-nav[data-module-nav-active-fqn-value='']"
    assert_select "aside.module-nav[data-module-nav-upstream-fqns-value='[]']"
  end

  test "module-nav header carries source name and version" do
    get entity_path(version: "v8.1.3", path: "active_record/persistence")
    assert_select ".module-nav__title", text: /Ruby on Rails/
    assert_select ".module-nav__title", text: /v8\.1\.3/
  end

  test "every page renders the accessibility scaffolding" do
    get root_path
    assert_response :success
    # Skip-to-main keyboard affordance, paired with the matching id on
    # <main> so Tab → Enter actually jumps content.
    assert_select "a.skip-link[href=?]", "#main-content", text: /Skip to main/
    assert_select "main#main-content"
    # Landmarks
    assert_select "header.site-header"
    assert_select "footer.site-footer"
  end

  test "every page emits a Content-Security-Policy header" do
    get root_path
    assert_response :success
    csp = response.headers["Content-Security-Policy"]
    assert csp.present?, "Expected CSP header to be set"
    assert_match(/default-src 'none'/, csp)
    assert_match(/script-src 'self' 'nonce-/, csp)
    assert_match(/frame-ancestors 'none'/, csp)
    assert_match(/object-src 'none'/, csp)
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

  test "all-caps constant slug round-trips through .underscore" do
    # ActionCable::INTERNAL — `.underscore` lowercases the constant
    # name to "internal" in the URL. The resolver has to undo that.
    constant = sources(:rails).entity_identities.create!(
      fqn: "Foo::INTERNAL",
      kind: "constant",
      name: "INTERNAL",
      parent_fqn: "Foo"
    )
    EntityVersion.create!(entity_identity: constant, package_version: package_versions(:v8_1_3))

    get entity_path(version: "v8.1.3", path: "foo/internal")
    assert_response :success
    assert_select "h1", text: /INTERNAL/
    assert_select ".entity__kind", "constant"
  end

  test "namespace with embedded acronym resolves through hierarchical walk" do
    # ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::SOMETHING —
    # `.camelize` of "postgre_sql_adapter" gives "PostgreSqlAdapter",
    # not "PostgreSQLAdapter", so the FQN-rebuild fast path misses
    # and the walker has to step through `name.underscore` matches.
    sources(:rails).entity_identities.create!(
      fqn: "Foo::HTTPAdapter",
      kind: "class",
      name: "HTTPAdapter",
      parent_fqn: "Foo"
    )
    constant = sources(:rails).entity_identities.create!(
      fqn: "Foo::HTTPAdapter::TIMEOUT",
      kind: "constant",
      name: "TIMEOUT",
      parent_fqn: "Foo::HTTPAdapter"
    )
    EntityVersion.create!(entity_identity: constant, package_version: package_versions(:v8_1_3))

    get entity_path(version: "v8.1.3", path: "foo/http_adapter/timeout")
    assert_response :success
    assert_select "h1", text: /TIMEOUT/
  end

  test "operator method slug round-trips through the URL" do
    sources(:rails).entity_identities.create!(
      fqn: "ActiveRecord::AttributeMethods",
      kind: "module",
      name: "AttributeMethods",
      parent_fqn: "ActiveRecord"
    )
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

  test "method page breadcrumbs separate parent module and method" do
    get entity_path(version: "v8.1.3", path: "active_record/persistence/save")
    assert_response :success
    # Three crumbs: ActiveRecord, Persistence (clickable), #save (current)
    assert_select ".breadcrumbs li a", text: "ActiveRecord"
    assert_select ".breadcrumbs li a", text: "Persistence"
    assert_select ".breadcrumbs li [aria-current='page']", text: "#save"
    # Persistence link goes to its module page (so the user can click up)
    assert_select ".breadcrumbs li a[href=?]", entity_path(version: "v8.1.3", path: "active_record/persistence"),
      text: "Persistence"
  end

  test "singleton method breadcrumbs show .name leaf" do
    singleton = sources(:rails).entity_identities.create!(
      fqn: "Foo.create",
      kind: "method",
      name: "create",
      scope: "singleton",
      parent_fqn: "Foo"
    )
    EntityVersion.create!(entity_identity: singleton, package_version: package_versions(:v8_1_3))
    get entity_path(version: "v8.1.3", path: "foo/create.class")
    assert_response :success
    assert_select ".breadcrumbs li [aria-current='page']", text: ".create"
  end

  test "constant breadcrumbs separate namespace and constant" do
    get entity_path(version: "v8.1.3", path: "foo/bar")
    assert_response :success
    assert_select ".breadcrumbs li a", text: "Foo"
    assert_select ".breadcrumbs li [aria-current='page']", text: "BAR"
  end

  test "class page splits methods into public + collapsed private sections" do
    private_meth = sources(:rails).entity_identities.create!(
      fqn: "ActiveRecord::Persistence#_save_record",
      kind: "method",
      name: "_save_record",
      scope: "instance",
      parent_fqn: "ActiveRecord::Persistence",
      framework: frameworks(:activerecord)
    )
    EntityVersion.create!(
      entity_identity: private_meth,
      package_version: package_versions(:v8_1_3),
      visibility: "private"
    )

    get entity_path(version: "v8.1.3", path: "active_record/persistence")
    assert_response :success
    # Public method shows in the main list, not the collapsed group
    assert_select ".entity__own-methods .method-list a", text: "save"
    # Private method shows inside the <details> block
    assert_select "details.method-group summary h2", text: "Private methods"
    assert_select ".entity__private-methods details .method-list a", text: "_save_record"
    # Outline link points at the private-methods anchor
    assert_select "aside .outline a[href='#section-private-methods']"
  end

  test "private method page renders a Private badge and meta-noindex" do
    private_meth = sources(:rails).entity_identities.create!(
      fqn: "ActiveRecord::Persistence#_callback",
      kind: "method",
      name: "_callback",
      scope: "instance",
      parent_fqn: "ActiveRecord::Persistence",
      framework: frameworks(:activerecord)
    )
    EntityVersion.create!(
      entity_identity: private_meth,
      package_version: package_versions(:v8_1_3),
      visibility: "private"
    )

    get entity_path(version: "v8.1.3", path: "active_record/persistence/_callback")
    assert_response :success
    assert_select ".badge.badge--private", text: "Private"
    assert_select 'meta[name="robots"][content="noindex"]', count: 1
    # JSON-LD TechArticle is suppressed for private methods
    assert_select 'script[type="application/ld+json"]', count: 0
  end

  test "module page lists nested classes and modules in the Namespace section" do
    EntityVersion.create!(entity_identity: entity_identities(:foo), package_version: package_versions(:v8_1_3))
    nested_module = sources(:rails).entity_identities.create!(
      fqn: "Foo::Encryption", kind: "module", name: "Encryption", parent_fqn: "Foo"
    )
    EntityVersion.create!(entity_identity: nested_module, package_version: package_versions(:v8_1_3))
    nested_class = sources(:rails).entity_identities.create!(
      fqn: "Foo::DangerousAttributeError", kind: "class", name: "DangerousAttributeError", parent_fqn: "Foo"
    )
    EntityVersion.create!(entity_identity: nested_class, package_version: package_versions(:v8_1_3))

    get entity_path(version: "v8.1.3", path: "foo")
    assert_response :success
    assert_select "section.entity__namespace h2", text: "Namespace"
    assert_select "section.entity__namespace h3", text: /Modules/
    assert_select "section.entity__namespace h3", text: /Classes/
    assert_select "section.entity__namespace a", text: "Foo::Encryption"
    assert_select "section.entity__namespace a", text: "Foo::DangerousAttributeError"
    # Outline links to the section
    assert_select "aside.entity__outline a[href='#section-namespace']"
  end

  test "Support and License sidebar block renders on entity pages" do
    get entity_path(version: "v8.1.3", path: "active_record/persistence")
    assert_response :success
    assert_select "aside .sidebar-block .sidebar-block__title", text: "Support"
    assert_select "aside .sidebar-block a[href=?]", "https://github.com/rails/rails/issues",
      text: /filed for the Ruby on Rails project on GitHub/
    assert_select "aside .sidebar-block a[href=?]", "https://discuss.rubyonrails.org/c/rubyonrails-core",
      text: /rubyonrails-core forum/
    assert_select "aside .sidebar-block .sidebar-block__title", text: "License"
    assert_select "aside .sidebar-block a[href=?]", "https://opensource.org/licenses/MIT", text: /MIT license/
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
