class CreateMethodVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :method_versions do |t|
      t.references :entity_version, null: false, foreign_key: true, index: { unique: true }
      t.text :yields
      t.text :return_doc
      t.references :aliased,
                   foreign_key: { to_table: :entity_identities },
                   index: { where: "aliased_id IS NOT NULL" }
      t.boolean :ghost, null: false, default: false

      t.timestamps
    end
  end
end
