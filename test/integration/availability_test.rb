require "test_helper"

# The "Available in" / "Compare with" strip on entity pages (rendered by
# entities/_availability). Focuses on the changed/same annotations in the
# compare picker, which are relative to the version the reader is viewing.
class AvailabilityTest < ActionDispatch::IntegrationTest
  setup do
    package_versions(:v8_1_3).update!(ingest_status: "ok", ingested_at: Time.current)
    package_versions(:v8_0_4).update!(ingest_status: "ok", ingested_at: Time.current)
    package_versions(:edge).update!(ingest_status: "ok", ingested_at: Time.current)

    # edge differs from v8.1.3; v8.0.4 fixture is byte-identical to v8.1.3.
    EntityVersion.create!(
      entity_identity: entity_identities(:ar_persistence_save),
      package_version: package_versions(:edge),
      doc_markdown: "Saves the model with extra magic.",
      signature_text: "(**options)"
    )
  end

  test "compare picker annotates versions as changed or same relative to the viewed version" do
    get entity_path(version: "v8.1.3", path: "active_record/persistence/save")
    assert_response :success

    assert_select "select[data-controller=?]", "diff-switcher" do
      assert_select "option", text: /edge · changed/     # content differs
      assert_select "option", text: /v8\.0\.4 · same/     # identical content
    end
  end

  test "annotations flip when viewing a different base version" do
    # Viewed from edge, v8.1.3 differs -> "changed".
    get entity_path(version: "edge", path: "active_record/persistence/save")
    assert_response :success
    assert_select "select[data-controller=?]", "diff-switcher" do
      assert_select "option", text: /v8\.1\.3 · changed/
    end
  end
end
