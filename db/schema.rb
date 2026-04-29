# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_28_000014) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "attribute_versions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "entity_version_id", null: false
    t.string "rw", null: false
    t.datetime "updated_at", null: false
    t.index ["entity_version_id"], name: "index_attribute_versions_on_entity_version_id", unique: true
  end

  create_table "class_versions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "entity_version_id", null: false
    t.bigint "superclass_identity_id"
    t.datetime "updated_at", null: false
    t.index ["entity_version_id"], name: "index_class_versions_on_entity_version_id", unique: true
    t.index ["superclass_identity_id"], name: "index_class_versions_on_superclass_identity_id", where: "(superclass_identity_id IS NOT NULL)"
  end

  create_table "constant_versions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "entity_version_id", null: false
    t.datetime "updated_at", null: false
    t.text "value_expr"
    t.index ["entity_version_id"], name: "index_constant_versions_on_entity_version_id", unique: true
  end

  create_table "entity_identities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "first_seen_version_id"
    t.string "fqn", null: false
    t.bigint "framework_id"
    t.string "kind", null: false
    t.bigint "last_seen_version_id"
    t.string "name", null: false
    t.string "parent_fqn"
    t.string "scope"
    t.bigint "source_id", null: false
    t.datetime "updated_at", null: false
    t.index ["first_seen_version_id"], name: "index_entity_identities_on_first_seen_version_id"
    t.index ["framework_id"], name: "index_entity_identities_on_framework_id"
    t.index ["last_seen_version_id"], name: "index_entity_identities_on_last_seen_version_id"
    t.index ["source_id", "fqn", "kind", "scope"], name: "idx_entity_identities_unique", unique: true, nulls_not_distinct: true
    t.index ["source_id", "parent_fqn"], name: "index_entity_identities_on_source_id_and_parent_fqn"
  end

  create_table "entity_versions", force: :cascade do |t|
    t.text "call_seq"
    t.datetime "created_at", null: false
    t.boolean "deprecated", default: false, null: false
    t.text "deprecation_note"
    t.text "doc_html"
    t.text "doc_markdown"
    t.text "doc_summary"
    t.bigint "entity_identity_id", null: false
    t.bigint "framework_id"
    t.bigint "last_ingest_run_id"
    t.bigint "package_version_id", null: false
    t.tsvector "search_vector"
    t.string "signature_text"
    t.text "source_code"
    t.integer "source_line_end"
    t.integer "source_line_start"
    t.string "source_path"
    t.datetime "updated_at", null: false
    t.string "visibility", default: "public", null: false
    t.index ["entity_identity_id", "package_version_id"], name: "idx_entity_versions_unique", unique: true
    t.index ["framework_id", "package_version_id"], name: "index_entity_versions_on_framework_id_and_package_version_id"
    t.index ["package_version_id"], name: "index_entity_versions_on_package_version_id"
    t.index ["search_vector"], name: "index_entity_versions_on_search_vector", using: :gin
  end

  create_table "frameworks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "display_name", null: false
    t.string "slug", null: false
    t.bigint "source_id", null: false
    t.datetime "updated_at", null: false
    t.index ["source_id", "slug"], name: "index_frameworks_on_source_id_and_slug", unique: true
  end

  create_table "inheritance_closures", primary_key: ["package_version_id", "descendant_identity_id", "ancestor_identity_id"], force: :cascade do |t|
    t.bigint "ancestor_identity_id", null: false
    t.integer "depth", null: false
    t.bigint "descendant_identity_id", null: false
    t.bigint "package_version_id", null: false
    t.string "via_relation", null: false
    t.index ["ancestor_identity_id"], name: "index_inheritance_closures_on_ancestor_identity_id"
    t.index ["package_version_id", "descendant_identity_id", "depth"], name: "idx_inheritance_closures_lookup"
  end

  create_table "inheritance_edges", force: :cascade do |t|
    t.bigint "ancestor_identity_id", null: false
    t.bigint "child_identity_id", null: false
    t.datetime "created_at", null: false
    t.bigint "package_version_id", null: false
    t.integer "position"
    t.string "relation", null: false
    t.datetime "updated_at", null: false
    t.index ["ancestor_identity_id"], name: "index_inheritance_edges_on_ancestor_identity_id"
    t.index ["child_identity_id"], name: "index_inheritance_edges_on_child_identity_id"
    t.index ["package_version_id", "child_identity_id", "ancestor_identity_id", "relation"], name: "idx_inheritance_edges_unique", unique: true
  end

  create_table "legacy_redirects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "entity_version_id", null: false
    t.string "old_path", null: false
    t.bigint "package_version_id", null: false
    t.datetime "updated_at", null: false
    t.index ["entity_version_id"], name: "index_legacy_redirects_on_entity_version_id"
    t.index ["package_version_id", "old_path"], name: "index_legacy_redirects_on_package_version_id_and_old_path", unique: true
  end

  create_table "method_params", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "default_expr"
    t.text "doc"
    t.bigint "entity_version_id", null: false
    t.string "kind", null: false
    t.string "name", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["entity_version_id", "position"], name: "index_method_params_on_entity_version_id_and_position", unique: true
  end

  create_table "method_versions", force: :cascade do |t|
    t.bigint "aliased_id"
    t.datetime "created_at", null: false
    t.bigint "entity_version_id", null: false
    t.boolean "ghost", default: false, null: false
    t.text "return_doc"
    t.datetime "updated_at", null: false
    t.text "yields"
    t.index ["aliased_id"], name: "index_method_versions_on_aliased_id", where: "(aliased_id IS NOT NULL)"
    t.index ["entity_version_id"], name: "index_method_versions_on_entity_version_id", unique: true
  end

  create_table "package_versions", force: :cascade do |t|
    t.string "channel", null: false
    t.datetime "created_at", null: false
    t.string "git_ref", null: false
    t.string "git_sha", null: false
    t.text "ingest_log"
    t.string "ingest_status", default: "pending", null: false
    t.datetime "ingested_at"
    t.integer "major"
    t.integer "minor"
    t.bigint "ord", null: false
    t.integer "patch"
    t.string "prerelease"
    t.string "release_series"
    t.date "released_on"
    t.bigint "source_id", null: false
    t.datetime "updated_at", null: false
    t.index ["release_series", "ord"], name: "index_package_versions_on_release_series_and_ord"
    t.index ["source_id", "channel"], name: "index_package_versions_on_source_id_and_channel", unique: true
  end

  create_table "sources", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "default_branch", default: "main", null: false
    t.string "display_name", null: false
    t.string "github_repo", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_sources_on_slug", unique: true
  end

  add_foreign_key "attribute_versions", "entity_versions"
  add_foreign_key "class_versions", "entity_identities", column: "superclass_identity_id"
  add_foreign_key "class_versions", "entity_versions"
  add_foreign_key "constant_versions", "entity_versions"
  add_foreign_key "entity_identities", "frameworks"
  add_foreign_key "entity_identities", "package_versions", column: "first_seen_version_id"
  add_foreign_key "entity_identities", "package_versions", column: "last_seen_version_id"
  add_foreign_key "entity_identities", "sources"
  add_foreign_key "entity_versions", "entity_identities"
  add_foreign_key "entity_versions", "frameworks"
  add_foreign_key "entity_versions", "package_versions"
  add_foreign_key "frameworks", "sources"
  add_foreign_key "inheritance_closures", "entity_identities", column: "ancestor_identity_id"
  add_foreign_key "inheritance_closures", "entity_identities", column: "descendant_identity_id"
  add_foreign_key "inheritance_closures", "package_versions"
  add_foreign_key "inheritance_edges", "entity_identities", column: "ancestor_identity_id"
  add_foreign_key "inheritance_edges", "entity_identities", column: "child_identity_id"
  add_foreign_key "inheritance_edges", "package_versions"
  add_foreign_key "legacy_redirects", "entity_versions"
  add_foreign_key "legacy_redirects", "package_versions"
  add_foreign_key "method_params", "entity_versions"
  add_foreign_key "method_versions", "entity_identities", column: "aliased_id"
  add_foreign_key "method_versions", "entity_versions"
  add_foreign_key "package_versions", "sources"
end
