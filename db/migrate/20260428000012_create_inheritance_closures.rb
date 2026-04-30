class CreateInheritanceClosures < ActiveRecord::Migration[8.1]
  def change
    create_table :inheritance_closures,
                 primary_key: [ :package_version_id, :descendant_identity_id, :ancestor_identity_id ] do |t|
      t.references :package_version, null: false, foreign_key: true, index: false
      t.references :descendant_identity, null: false,
                   foreign_key: { to_table: :entity_identities },
                   index: false
      t.references :ancestor_identity, null: false,
                   foreign_key: { to_table: :entity_identities }
      t.integer :depth, null: false
      t.string :via_relation, null: false
    end

    add_index :inheritance_closures,
              [ :package_version_id, :descendant_identity_id, :depth ],
              name: "idx_inheritance_closures_lookup"
  end
end
