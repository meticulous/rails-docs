class HomeController < ApplicationController
  def index
    @package_versions = PackageVersion.ok.where.not(ingested_at: nil).order(ord: :desc)
  end
end
