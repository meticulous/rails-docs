class CreateClassVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :class_versions do |t|
      t.references :entity_version, null: false, foreign_key: true, index: { unique: true }
      t.references :superclass_identity,
                   foreign_key: { to_table: :entity_identities },
                   index: { where: "superclass_identity_id IS NOT NULL" }

      t.timestamps
    end
  end
end
