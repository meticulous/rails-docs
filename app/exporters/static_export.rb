require "fileutils"

# Renders every entity page in a PackageVersion as a static HTML file.
# Reuses the live controller + view pipeline so the output is byte-identical
# to what a live request would produce.
class StaticExport
  attr_reader :package_version, :base_dir, :available_versions

  def initialize(package_version, base_dir, available_versions: nil)
    @package_version = package_version
    @base_dir = base_dir
    @available_versions = available_versions || PackageVersion.where.not(ingested_at: nil).order(ord: :desc).to_a
  end

  def run
    FileUtils.mkdir_p(version_dir)
    started_at = Time.now
    count = 0

    package_version.entity_versions.preload(:entity_identity).find_each(batch_size: 250) do |ev|
      write_entity(ev)
      count += 1
      print "." if count % 100 == 0
    end

    puts
    puts "Exported #{count} entity pages for #{package_version.channel} in #{(Time.now - started_at).round(1)}s → #{version_dir}"
  end

  private

  def version_dir
    File.join(base_dir, version_segment)
  end

  def version_segment
    package_version.channel == "edge" ? "edge" : "v#{package_version.channel}"
  end

  def write_entity(entity_version)
    identity = entity_version.entity_identity
    relative_path = entity_relative_path(identity)
    return unless relative_path

    output_path = File.join(version_dir, "#{relative_path}.html")
    FileUtils.mkdir_p(File.dirname(output_path))
    File.write(output_path, render_entity(entity_version))
  end

  def render_entity(entity_version)
    identity = entity_version.entity_identity
    template, presenter_class = case identity.kind
    when "method" then [ "entities/method", MethodPresenter ]
    else [ "entities/class", ClassPresenter ]
    end

    renderer.render(
      template: template,
      assigns: {
        package_version: package_version,
        identity: identity,
        entity_version: entity_version,
        presenter: presenter_class.new(entity_version),
        available_versions: available_versions
      },
      layout: "application"
    )
  end

  def renderer
    @renderer ||= EntitiesController.renderer.new(
      https: true,
      method: "get",
      http_host: ENV.fetch("CANONICAL_HOST", "api.rubyonrails.org")
    )
  end

  def entity_relative_path(identity)
    case identity.kind
    when "class", "module", "constant"
      identity.url_path
    when "method"
      slug = MethodSlug.encode(identity.name)
      slug = "#{slug}.class" if identity.scope == "singleton"
      "#{EntityIdentity.fqn_to_url_path(identity.parent_fqn)}/#{slug}"
    when "attribute"
      "#{EntityIdentity.fqn_to_url_path(identity.parent_fqn)}/#{identity.name}"
    end
  end
end
