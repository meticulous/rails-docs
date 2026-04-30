# Branded error pages rendered through the app layout (header, search,
# theme toggle, footer all work). Hooked up in production via
# `config.exceptions_app = routes` so requests that raise are
# re-dispatched to one of these actions; the controller respects the
# original status code from `request.path`.
class ErrorsController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  def not_found
    @available_versions = PackageVersion.where.not(ingested_at: nil).order(ord: :desc)
    render :not_found, status: 404
  end

  def unprocessable_entity
    render :unprocessable_entity, status: 422
  end

  def internal_server_error
    render :internal_server_error, status: 500
  end
end
