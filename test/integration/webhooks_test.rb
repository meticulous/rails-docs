require "test_helper"

class WebhooksTest < ActionDispatch::IntegrationTest
  SECRET = "test-secret".freeze

  setup do
    ENV["INGEST_WEBHOOK_SECRET"] = SECRET
  end

  teardown do
    ENV.delete("INGEST_WEBHOOK_SECRET")
  end

  test "rejects unsigned requests with 401" do
    post "/webhooks/ingest", params: payload.to_json,
                              headers: { "Content-Type" => "application/json" }
    assert_response :unauthorized
  end

  test "rejects requests with a wrong signature" do
    post "/webhooks/ingest", params: payload.to_json, headers: signed_headers("wrong-secret", payload.to_json)
    assert_response :unauthorized
  end

  test "accepts a properly-signed request and enqueues the job" do
    body = payload.to_json
    assert_enqueued_with(job: IngestPackageVersionJob) do
      post "/webhooks/ingest", params: body, headers: signed_headers(SECRET, body)
    end
    assert_response :accepted
  end

  test "rejects a signed request with an incomplete payload" do
    body = payload.except("source_slug").to_json
    post "/webhooks/ingest", params: body, headers: signed_headers(SECRET, body)
    assert_response :bad_request
  end

  private

  def payload
    {
      "source_slug" => "rails",
      "channel" => "8.1.3",
      "git_ref" => "v8.1.3",
      "git_sha" => "abcdef0123",
      "ord" => 8001003,
      "source_dirs" => ["activesupport/lib", "activerecord/lib"]
    }
  end

  def signed_headers(secret, body)
    {
      "Content-Type" => "application/json",
      "X-Hub-Signature-256" => "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", secret, body)
    }
  end
end
