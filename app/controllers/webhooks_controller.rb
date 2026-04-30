# Receives release notifications and enqueues IngestPackageVersionJob.
#
# Auth: HMAC-SHA256 signature in the X-Hub-Signature-256 header (matches
# the GitHub-webhook convention). The shared secret comes from Rails
# credentials (Rails.application.credentials.dig(:webhooks, :ingest_secret)).
#
# Payload shape (POST /webhooks/ingest):
#   {
#     "source_slug": "rails",
#     "channel": "8.1.3",
#     "git_ref": "v8.1.3",
#     "git_sha": "abcdef01234567",
#     "ord": 8001003,
#     "source_dirs": ["activesupport/lib", "activerecord/lib", ...]
#   }
class WebhooksController < ApplicationController
  protect_from_forgery with: :null_session

  def ingest
    return head :unauthorized unless valid_signature?

    payload = parsed_payload
    return head :bad_request unless valid_payload?(payload)

    IngestPackageVersionJob.perform_later(
      source_slug: payload["source_slug"],
      channel: payload["channel"],
      git_ref: payload["git_ref"],
      git_sha: payload["git_sha"],
      ord: payload["ord"].to_i,
      source_dirs: Array(payload["source_dirs"])
    )

    head :accepted
  end

  private

  def shared_secret
    Rails.application.credentials.dig(:webhooks, :ingest_secret) || ENV["INGEST_WEBHOOK_SECRET"]
  end

  def valid_signature?
    secret = shared_secret
    return false if secret.blank?

    header = request.headers["X-Hub-Signature-256"].to_s
    return false unless header.start_with?("sha256=")

    expected = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", secret, request.raw_post)
    ActiveSupport::SecurityUtils.secure_compare(header, expected)
  end

  def parsed_payload
    JSON.parse(request.raw_post)
  rescue JSON::ParserError
    {}
  end

  def valid_payload?(payload)
    %w[source_slug channel git_ref git_sha ord].all? { |k| payload[k].present? }
  end
end
