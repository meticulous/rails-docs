class CreateEntityVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :entity_versions do |t|
      t.references :entity_identity, null: false, foreign_key: true, index: false
      t.references :package_version, null: false, foreign_key: true
      t.references :framework, foreign_key: true, index: false
      t.string :visibility, null: false, default: "public"
      t.boolean :deprecated, null: false, default: false
      t.text :deprecation_note
      t.text :doc_markdown
      t.text :doc_html
      t.text :doc_summary
      t.string :source_path
      t.integer :source_line_start
      t.integer :source_line_end
      t.text :source_code
      t.string :signature_text
      t.text :call_seq
      t.tsvector :search_vector
      t.bigint :last_ingest_run_id

      t.timestamps
    end

    add_index :entity_versions,
              [ :entity_identity_id, :package_version_id ],
              unique: true,
              name: "idx_entity_versions_unique"
    add_index :entity_versions, :search_vector, using: :gin
    add_index :entity_versions, [ :framework_id, :package_version_id ]
  end
end
