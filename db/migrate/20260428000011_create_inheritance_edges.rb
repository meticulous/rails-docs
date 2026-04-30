class CreateInheritanceEdges < ActiveRecord::Migration[8.1]
  def change
    create_table :inheritance_edges do |t|
      t.references :package_version, null: false, foreign_key: true, index: false
      t.references :child_identity, null: false, foreign_key: { to_table: :entity_identities }
      t.references :ancestor_identity, null: false, foreign_key: { to_table: :entity_identities }
      t.string :relation, null: false
      t.integer :position

      t.timestamps
    end

    add_index :inheritance_edges,
              [ :package_version_id, :child_identity_id, :ancestor_identity_id, :relation ],
              unique: true,
              name: "idx_inheritance_edges_unique"
  end
end
