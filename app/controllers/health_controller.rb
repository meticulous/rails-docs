# Application-level health probe. /up remains the Rails-default boot-OK
# probe; /health adds checks that matter for this app:
#
#   * Postgres connectivity
#   * Search adapter healthy (entity_versions have search_vector)
#   * At least one package_version ingested
#   * Most-recent ingest is within INGEST_FRESHNESS_DAYS days
#
# Returns JSON with overall status + per-check details. Returns 503 when
# any check fails so monitors can alert.
class HealthController < ApplicationController
  INGEST_FRESHNESS_DAYS = 31

  def show
    checks = [
      database_check,
      search_adapter_check,
      package_version_present_check,
      ingest_freshness_check
    ]
    overall = checks.all? { |c| c[:status] == "ok" } ? "ok" : "degraded"
    status_code = overall == "ok" ? :ok : :service_unavailable

    render json: { status: overall, checks: checks }, status: status_code
  end

  private

  def database_check
    ApplicationRecord.connection.execute("SELECT 1")
    { name: "database", status: "ok" }
  rescue StandardError => e
    { name: "database", status: "fail", details: e.message }
  end

  def search_adapter_check
    if SearchAdapter.current.healthcheck
      { name: "search_adapter", status: "ok" }
    else
      { name: "search_adapter", status: "fail", details: "no entity_versions have search_vector populated" }
    end
  rescue StandardError => e
    { name: "search_adapter", status: "fail", details: e.message }
  end

  def package_version_present_check
    count = PackageVersion.where.not(ingested_at: nil).count
    return { name: "package_versions_present", status: "fail", details: "no package_versions ingested" } if count.zero?
    { name: "package_versions_present", status: "ok", details: "#{count} ingested" }
  end

  def ingest_freshness_check
    most_recent = PackageVersion.where.not(ingested_at: nil).maximum(:ingested_at)
    return { name: "ingest_freshness", status: "fail", details: "no ingest_at timestamps" } unless most_recent

    age_days = ((Time.current - most_recent) / 1.day).round(1)
    if age_days <= INGEST_FRESHNESS_DAYS
      { name: "ingest_freshness", status: "ok", details: "last ingest #{age_days}d ago" }
    else
      { name: "ingest_freshness", status: "fail", details: "last ingest #{age_days}d ago (>#{INGEST_FRESHNESS_DAYS}d)" }
    end
  end
end
