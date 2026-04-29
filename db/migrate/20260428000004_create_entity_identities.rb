class CreateEntityIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :entity_identities do |t|
      t.references :source, null: false, foreign_key: true, index: false
      t.string :fqn, null: false
      t.string :kind, null: false
      t.string :parent_fqn
      t.string :name, null: false
      t.string :scope
      t.references :framework, foreign_key: true
      t.references :first_seen_version, foreign_key: { to_table: :package_versions }
      t.references :last_seen_version, foreign_key: { to_table: :package_versions }

      t.timestamps
    end

    add_index :entity_identities,
              [:source_id, :fqn, :kind, :scope],
              unique: true,
              name: "idx_entity_identities_unique"
    add_index :entity_identities, [:source_id, :parent_fqn]
  end
end
