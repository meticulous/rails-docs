require "application_system_test_case"

# Click-driven tests that exercise the JS-only behaviors (theme toggle,
# version dropdown navigation, search box submit). The integration tests
# in test/integration cover the SSR rendering; this file is for behaviors
# that need a real browser.
#
# These can later swap to capybara-playwright-driver by changing the
# driven_by line in application_system_test_case.rb — no test edits needed.
class EntityBrowsingSystemTest < ApplicationSystemTestCase
  setup do
    package_versions(:v8_1_3).update!(ingest_status: "ok", ingested_at: Time.current)
  end

  test "theme toggle cycles light → dark → system" do
    visit entity_path(version: "v8.1.3", path: "active_record/persistence")
    html = find("html")
    assert_nil html[:"data-theme"]

    find(".theme-toggle").click
    assert_equal "light", html[:"data-theme"]

    find(".theme-toggle").click
    assert_equal "dark", html[:"data-theme"]

    find(".theme-toggle").click
    assert_nil html[:"data-theme"]
  end

  test "search box in header submits and renders results" do
    visit root_path
    fill_in :q, with: "save"
    find(".site-header__search input[name=q]").send_keys(:return)
    assert_selector "h1", text: "Search"
    assert_current_path(/\/search/)
  end

  test "cmd-K opens the search palette" do
    visit root_path
    # Selenium's send_keys handles meta+k as a chord at the OS level —
    # which doesn't reach the page in headless Chrome. Dispatching the
    # KeyboardEvent directly proves the wiring (Stimulus action ->
    # search-palette#open) without depending on the OS-level chord.
    evaluate_script(
      "document.dispatchEvent(new KeyboardEvent('keydown', { key: 'k', metaKey: true, bubbles: true }));" \
      "window.dispatchEvent(new KeyboardEvent('keydown', { key: 'k', metaKey: true, bubbles: true }));"
    )
    assert_selector "dialog.palette[open]", visible: :all
  end

  test '"/" focuses the inline header search box' do
    visit root_path
    page.send_keys "/"
    active_name = evaluate_script("document.activeElement.name")
    assert_equal "q", active_name, "Expected the q input to receive focus on /"
  end
end
