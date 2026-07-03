require "test_helper"

class DiffTest < ActionDispatch::IntegrationTest
  setup do
    package_versions(:v8_1_3).update!(ingest_status: "ok", ingested_at: Time.current)
    package_versions(:edge).update!(ingest_status: "ok", ingested_at: Time.current)

    @save_in_v8 = entity_versions(:ar_persistence_save_v8_1_3)
    # v8.0.4 fixture is byte-identical content to v8.1.3 -> "same" annotation.
    @save_in_v8_0 = entity_versions(:ar_persistence_save_v8_0_4)
    @save_in_edge = EntityVersion.create!(
      entity_identity: entity_identities(:ar_persistence_save),
      package_version: package_versions(:edge),
      doc_markdown: "Saves the model with extra magic.",
      signature_text: "(**options, validate: true)"
    )
  end

  test "renders the diff between two versions when both have the entity" do
    get diff_path(version: "v8.1.3", entity_path: "active_record/persistence/save", other_version: "edge")
    assert_response :success
    assert_select "h1", text: /ActiveRecord::Persistence#save/
    assert_select ".diff__section h2", text: "Documentation"
  end

  test "renders 'Added' status when the entity is missing in the from version" do
    @save_in_v8.destroy
    get diff_path(version: "v8.1.3", entity_path: "active_record/persistence/save", other_version: "edge")
    assert_response :success
    assert_select ".diff__status--added"
  end

  test "renders 'Removed' status when the entity is missing in the to version" do
    @save_in_edge.destroy
    get diff_path(version: "v8.1.3", entity_path: "active_record/persistence/save", other_version: "edge")
    assert_response :success
    assert_select ".diff__status--removed"
  end

  test "404 when the entity does not exist in either version" do
    get diff_path(version: "v8.1.3", entity_path: "does/not/exist", other_version: "edge")
    assert_response :not_found
  end

  test "diff header renders inline base and compare version pickers" do
    get diff_path(version: "v8.1.3", entity_path: "active_record/persistence/save", other_version: "edge")
    assert_response :success
    assert_select "select#diff-base-version[data-action=?]", "change->diff-switcher#go"
    assert_select "select#diff-compare-version[data-action=?]", "change->diff-switcher#go"
    # Base picker pre-selects v8.1.3; compare picker pre-selects edge.
    assert_select "select#diff-base-version option[selected]", text: /v8\.1\.3/
    assert_select "select#diff-compare-version option[selected]", text: /edge/
    # Plain escape hatch back to the base version without the diff.
    assert_select "a.diff__switch-plain", text: /without diff/
  end

  test "compare picker annotates each version as changed or same" do
    get diff_path(version: "v8.1.3", entity_path: "active_record/persistence/save", other_version: "edge")
    assert_response :success
    # edge content differs from base v8.1.3 -> "changed"
    assert_select "select#diff-compare-version option", text: /edge · changed/
    # v8.0.4 content is identical to base v8.1.3 -> "same"
    assert_select "select#diff-compare-version option", text: /v8\.0\.4 · same/
  end

  test "renders a collapsed source diff when source_code changed" do
    @save_in_v8.update!(source_code: "def save(**options)\n  create_or_update(**options)\nend")
    @save_in_edge.update!(source_code: "def save(**options, &block)\n  create_or_update(**options, &block)\nend")

    get diff_path(version: "v8.1.3", entity_path: "active_record/persistence/save", other_version: "edge")
    assert_response :success
    assert_select ".diff__section--source h2", text: "Source"
    # Collapsed by default, heading outside the summary's button role.
    assert_select ".diff__section--source details:not([open]) summary", text: /Show source changes/
    assert_select ".diff__section--source details summary h2", false
    assert_select ".diff__section--source .diff-line--added", text: /&block/
  end

  test "source-only change annotates the compare picker and shows no identical banner" do
    # Same doc + signature as base, different source: without source in
    # the digest this said "same" while the page had changes to show.
    @save_in_edge.update!(
      doc_markdown: @save_in_v8.doc_markdown,
      signature_text: @save_in_v8.signature_text,
      source_code: "def save; magic; end"
    )
    @save_in_v8.update!(source_code: "def save; end")

    get diff_path(version: "v8.1.3", entity_path: "active_record/persistence/save", other_version: "edge")
    assert_response :success
    assert_select "select#diff-compare-version option", text: /edge · changed/
    assert_select ".diff__status--unchanged", false
    assert_select ".diff__section--source"
  end

  test "identical banner covers source and only shows when nothing differs" do
    get diff_path(version: "v8.1.3", entity_path: "active_record/persistence/save", other_version: "v8.0.4")
    assert_response :success
    assert_select ".diff__status--unchanged", text: /Signature, documentation, and source are identical/
    assert_select ".diff__section--source", false
  end
end
