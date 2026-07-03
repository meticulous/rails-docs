require "test_helper"

class SearchTest < ActionDispatch::IntegrationTest
  setup do
    package_versions(:v8_1_3).update!(ingest_status: "ok", ingested_at: Time.current)
    populate_search_vector!(entity_versions(:ar_persistence_save_v8_1_3))
    populate_search_vector!(entity_versions(:ar_persistence_v8_1_3))
    populate_search_vector!(entity_versions(:ar_base_v8_1_3))
  end

  test "blank query renders the prompt" do
    get search_path
    assert_response :success
    assert_select "h1", "Search"
    assert_select ".muted", text: /Type a query/
  end

  test "matching query returns results ordered by ts_rank_cd" do
    get search_path, params: { q: "save" }
    assert_response :success
    assert_select ".search-result__name", minimum: 1
    assert_select ".search-result a", text: "ActiveRecord::Persistence#save"
  end

  test "exact name match ranks first over docs that merely mention the term" do
    # A method literally named `before_action`, plus a decoy method whose
    # name only contains "action" but whose docs mention "before" — under
    # plain FTS (which stems before_action -> befor & action) the decoy
    # can outrank the real method. The exact-name boost must fix that.
    exact = sources(:rails).entity_identities.create!(
      fqn: "AbstractController::Callbacks::ClassMethods#before_action",
      kind: "method", name: "before_action", scope: "instance",
      parent_fqn: "AbstractController::Callbacks::ClassMethods", framework: frameworks(:activerecord)
    )
    exact_ev = EntityVersion.create!(
      entity_identity: exact, package_version: package_versions(:v8_1_3),
      doc_markdown: "Append a callback."
    )
    decoy = sources(:rails).entity_identities.create!(
      fqn: "Turbo::Broadcastable#broadcast_action_to",
      kind: "method", name: "broadcast_action_to", scope: "instance",
      parent_fqn: "Turbo::Broadcastable", framework: frameworks(:activerecord)
    )
    decoy_ev = EntityVersion.create!(
      entity_identity: decoy, package_version: package_versions(:v8_1_3),
      doc_markdown: "Broadcast an action before and after rendering the partial."
    )
    populate_search_vector!(exact_ev)
    populate_search_vector!(decoy_ev)

    response = SearchAdapter.current.search(query: "before_action", limit: 5)
    assert_equal "AbstractController::Callbacks::ClassMethods#before_action",
                 response.results.first.entity_version.entity_identity.fqn,
                 "exact-name match should rank first"
  end

  test "non-matching query returns no results" do
    get search_path, params: { q: "asdfqwerzxcvnoresult" }
    assert_response :success
    assert_select ".muted", text: /No results/
  end

  test "version filter restricts to a package_version" do
    get search_path, params: { q: "save", version: "vedge" }
    assert_response :success
    # edge fixture has no entity_versions wired up, so 0 results
    assert_select ".muted", text: /No results/
  end

  test "/search/suggest declares a rate-limit before_action" do
    # The controller is wired with `rate_limit to: 60, within: 1.minute`;
    # functional behavior under load is exercised by Rails' own
    # rate_limit test suite. We assert the wiring is in place.
    assert SearchController._process_action_callbacks
                          .map(&:filter)
                          .map(&:to_s)
                          .grep(/rate_limit/i).any?,
           "Expected SearchController to register a rate_limit callback"
  end

  test "/search/suggest returns the full fqn as a single string for client-side splitting" do
    # The ⌘K palette de-emphasizes the containing path (everything up to
    # the last :: or #) client-side, so the JSON must keep shipping the
    # plain fqn rather than pre-splitting it server-side.
    get search_suggest_path, params: { q: "save" }
    assert_response :success

    body = JSON.parse(response.body)
    result = body["results"].find { |r| r["fqn"] == "ActiveRecord::Persistence#save" }
    assert result, "expected a suggest result for ActiveRecord::Persistence#save"
    assert_equal "ActiveRecord::Persistence#save", result["fqn"]
  end

  test "search palette dialog is present on every page and closes via Escape regardless of input focus" do
    # Safari/WebKit swallows Escape on a focused type=search input to
    # clear its value, so the fix binds keydown->search-palette#onKeydown
    # on the input itself (not just the dialog) and handles "Escape"
    # explicitly in the controller rather than relying on native
    # dialog cancel behavior. Assert the markup wiring that makes that
    # possible is actually rendered.
    get search_path
    assert_response :success

    assert_select "dialog.palette[data-search-palette-target='dialog']" do
      assert_select "input#palette-input[data-search-palette-target='input']" do |inputs|
        actions = inputs.first["data-action"]
        assert_match(/keydown->search-palette#onKeydown/, actions,
                     "Escape must be handled on the input itself, since WebKit " \
                     "consumes Escape on a focused type=search input before " \
                     "it can reach the dialog's native cancel handling")
      end
    end
  end

  test "keyboard shortcuts help dialog is present on every page and wired to close on Escape/backdrop click" do
    get search_path
    assert_response :success

    assert_select "dialog.shortcuts-help" do |dialogs|
      actions = dialogs.first["data-action"]
      assert_match(/click->keyboard#closeHelp/, actions)
      assert_match(/keydown->keyboard#closeHelp/, actions)
      assert_select "kbd", text: "/"
      assert_select "kbd", text: "?"
      assert_select "kbd", text: "Esc"
    end
  end

  private

  def populate_search_vector!(entity_version)
    ApplicationRecord.connection.execute(<<~SQL)
      UPDATE entity_versions
      SET search_vector =
        setweight(to_tsvector('english', COALESCE((SELECT name FROM entity_identities WHERE id = #{entity_version.entity_identity_id}), '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(signature_text, '')), 'B') ||
        setweight(to_tsvector('english', COALESCE(doc_summary, '')), 'C') ||
        setweight(to_tsvector('english', COALESCE(doc_markdown, '')), 'D')
      WHERE id = #{Integer(entity_version.id)}
    SQL
  end
end
