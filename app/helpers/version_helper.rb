module VersionHelper
  def version_url_segment(package_version)
    package_version.channel == "edge" ? "edge" : "v#{package_version.channel}"
  end

  def version_label(package_version)
    version_url_segment(package_version)
  end

  # Label for a version option in a diff/compare picker, annotated with
  # whether that version's content differs from the reference version, e.g.
  # "v7.1.6 · changed" or "v8.0.4 · same".
  def version_diff_option_label(package_version, changed:)
    "#{version_label(package_version)} · #{changed ? 'changed' : 'same'}"
  end

  # Heading for a major-series group on the home page version list, e.g.
  # "8.x" for major == 8, or "Edge" for the placeholder major used to
  # bucket the edge channel (which has no numbered series of its own).
  def version_group_label(major)
    major == Float::INFINITY ? "Edge" : "#{major}.x"
  end
end
