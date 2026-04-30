require "test_helper"

class StaticExportTest < ActiveSupport::TestCase
  setup do
    @tmp = Dir.mktmpdir("static_export_test")
    package_versions(:v8_1_3).update!(ingest_status: "ok", ingested_at: Time.current)
  end

  teardown do
    FileUtils.rm_rf(@tmp) if @tmp
  end

  test "writes one HTML file per entity_version" do
    StaticExport.new(package_versions(:v8_1_3), @tmp).run

    expected_files = [
      "v8.1.3/active_record/base.html",
      "v8.1.3/active_record/persistence.html",
      "v8.1.3/active_record/persistence/save.html",
      "v8.1.3/foo/name.html",
      "v8.1.3/foo/BAR.html"
    ]
    expected_files.each do |f|
      assert File.exist?(File.join(@tmp, f)), "expected #{f} to exist"
    end
  end

  test "rendered HTML contains entity content" do
    StaticExport.new(package_versions(:v8_1_3), @tmp).run

    html = File.read(File.join(@tmp, "v8.1.3/active_record/persistence/save.html"))
    assert_includes html, "ActiveRecord::Persistence#save"
    assert_includes html, "Saves the record."
    assert_includes html, "<title>"
  end

  test "singleton methods get .class suffix in path" do
    singleton = sources(:rails).entity_identities.create!(
      fqn: "ActiveRecord::Persistence.create",
      kind: "method",
      name: "create",
      scope: "singleton",
      parent_fqn: "ActiveRecord::Persistence"
    )
    EntityVersion.create!(entity_identity: singleton, package_version: package_versions(:v8_1_3))

    StaticExport.new(package_versions(:v8_1_3), @tmp).run
    assert File.exist?(File.join(@tmp, "v8.1.3/active_record/persistence/create.class.html"))
  end
end
