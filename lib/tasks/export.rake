require "fileutils"

namespace :export do
  desc <<~DESC
    Render entity pages as static HTML.
      bin/rails export:static                 # all ingested versions
      bin/rails export:static VERSION=8.1.2   # one version
      bin/rails export:static OUT=path/dir    # output dir (default tmp/export)
  DESC
  task static: :environment do
    out_dir = ENV.fetch("OUT", Rails.root.join("tmp/export").to_s)
    requested = ENV["VERSION"]

    versions = PackageVersion.where.not(ingested_at: nil).order(:ord)
    versions = versions.where(channel: requested) if requested && requested != "all"

    if versions.empty?
      abort "No ingested versions match #{requested.inspect}"
    end

    available_versions = versions.to_a
    versions.each do |pv|
      StaticExport.new(pv, out_dir, available_versions: available_versions).run
    end
  end
end
