require "test_helper"

# Integration coverage for the branded error pages. We can't `get "/404"`
# directly — Rack::Files serves `public/404.html` before the router gets
# a chance — so each test temporarily appends an `/errors/*` route that
# bypasses the static-file middleware and exercises the same controller
# action. In production, ActionDispatch::ShowExceptions translates
# raised errors into a request for `/404`, `/422`, or `/500`, and
# `config.exceptions_app = routes` hands those off to ErrorsController.
class ErrorsTest < ActionDispatch::IntegrationTest
  test "errors#not_found renders a branded page with site chrome" do
    with_temp_route("/test_errors/not_found", "errors#not_found") do
      get "/test_errors/not_found"
      assert_response :not_found
      assert_select "h1", "We couldn't find that page."
      assert_select "a[href=?]", search_path, text: "open search"
      assert_select ".site-header"
    end
  end

  test "errors#unprocessable_entity renders a branded 422" do
    with_temp_route("/test_errors/422", "errors#unprocessable_entity") do
      get "/test_errors/422"
      assert_response :unprocessable_entity
      assert_select "h1", "That request couldn't be processed."
    end
  end

  test "errors#internal_server_error renders a branded 500" do
    with_temp_route("/test_errors/500", "errors#internal_server_error") do
      get "/test_errors/500"
      assert_response :internal_server_error
      assert_select "h1", "Something went wrong on our end."
    end
  end

  test "the not_found page lists ingested versions when present" do
    package_versions(:v8_1_3).update!(ingest_status: "ok", ingested_at: Time.current)

    with_temp_route("/test_errors/not_found", "errors#not_found") do
      get "/test_errors/not_found"
      assert_response :not_found
      assert_select "a", text: "v8.1.3"
    end
  end

  private

  # Append-and-restore: ActionDispatch routes can be appended to without
  # blowing away the existing table, so all the named helpers
  # (search_path, root_path, etc.) the views rely on remain intact.
  def with_temp_route(path, controller_action)
    Rails.application.routes.append do
      get path, to: controller_action
    end
    Rails.application.reload_routes!
    yield
  ensure
    Rails.application.reload_routes!
  end
end
