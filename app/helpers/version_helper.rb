module VersionHelper
  def version_url_segment(package_version)
    package_version.channel == "edge" ? "edge" : "v#{package_version.channel}"
  end

  def version_label(package_version)
    version_url_segment(package_version)
  end
end
