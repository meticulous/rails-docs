require "fileutils"
require "sqlite3"

# Builds a Dash docset from a static HTML export of one PackageVersion.
# Dash docsets are bundle directories laid out as:
#
#   RubyOnRails-8.1.2.docset/
#     Contents/
#       Info.plist                      ← metadata read by Dash on import
#       Resources/
#         docSet.dsidx                  ← SQLite searchIndex
#         Documents/                    ← HTML tree (mirrors web URLs)
#           active_record/base.html
#           active_record/persistence/save.html
#           ...
class DashExport
  attr_reader :package_version, :static_dir, :out_dir

  def initialize(package_version:, static_dir:, out_dir: nil)
    @package_version = package_version
    @static_dir = static_dir
    @out_dir = out_dir || Rails.root.join("tmp/export").to_s
  end

  def run
    docset = bundle_path
    FileUtils.rm_rf(docset)
    FileUtils.mkdir_p(documents_dir(docset))

    write_info_plist(docset)
    copy_documents(docset)
    write_search_index(docset)

    puts "Built Dash docset: #{docset}"
    docset
  end

  def self.dash_type(kind)
    {
      "module" => "Module",
      "class" => "Class",
      "method" => "Method",
      "constant" => "Constant",
      "attribute" => "Attribute"
    }[kind] || "Entry"
  end

  private

  def bundle_path
    File.join(out_dir, "RubyOnRails-#{package_version.channel}.docset")
  end

  def documents_dir(docset)
    File.join(docset, "Contents", "Resources", "Documents")
  end

  def version_segment
    package_version.channel == "edge" ? "edge" : "v#{package_version.channel}"
  end

  def write_info_plist(docset)
    File.write(File.join(docset, "Contents", "Info.plist"), info_plist_xml)
  end

  def info_plist_xml
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>CFBundleIdentifier</key><string>rubyonrails</string>
        <key>CFBundleName</key><string>Ruby on Rails #{package_version.channel}</string>
        <key>DocSetPlatformFamily</key><string>rails</string>
        <key>isDashDocset</key><true/>
        <key>dashIndexFilePath</key><string>active_record/base.html</string>
        <key>DashDocSetFamily</key><string>dashtoc</string>
      </dict>
      </plist>
    XML
  end

  def copy_documents(docset)
    source = File.join(static_dir, version_segment)
    raise "No static export found at #{source}; run rake export:static first" unless File.directory?(source)
    FileUtils.cp_r(File.join(source, "."), documents_dir(docset))
  end

  def write_search_index(docset)
    db_path = File.join(docset, "Contents", "Resources", "docSet.dsidx")
    File.delete(db_path) if File.exist?(db_path)
    db = SQLite3::Database.new(db_path)
    db.execute_batch <<~SQL
      CREATE TABLE searchIndex(id INTEGER PRIMARY KEY, name TEXT, type TEXT, path TEXT);
      CREATE UNIQUE INDEX anchor ON searchIndex (name, type, path);
    SQL

    db.transaction do
      package_version.entity_versions
                     .preload(:entity_identity)
                     .find_each(batch_size: 500) do |ev|
        identity = ev.entity_identity
        path = static_relative_path(identity)
        next unless path
        begin
          db.execute(
            "INSERT INTO searchIndex(name, type, path) VALUES (?, ?, ?)",
            [ identity.fqn, self.class.dash_type(identity.kind), path ]
          )
        rescue SQLite3::ConstraintException
          # Skip duplicates (rare; same name/type/path collision)
        end
      end
    end
    db.close
  end

  def static_relative_path(identity)
    case identity.kind
    when "class", "module", "constant"
      "#{identity.url_path}.html"
    when "method"
      slug = MethodSlug.encode(identity.name)
      slug = "#{slug}.class" if identity.scope == "singleton"
      "#{EntityIdentity.fqn_to_url_path(identity.parent_fqn)}/#{slug}.html"
    when "attribute"
      "#{EntityIdentity.fqn_to_url_path(identity.parent_fqn)}/#{identity.name}.html"
    end
  end
end
