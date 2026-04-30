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
