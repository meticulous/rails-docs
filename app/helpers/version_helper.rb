module VersionHelper
  def version_url_segment(package_version)
    channel = package_version.respond_to?(:channel) ? package_version.channel : package_version.to_s
    channel == "edge" ? "edge" : "v#{channel}"
  end

  def version_label(package_version)
    version_url_segment(package_version)
  end
end
