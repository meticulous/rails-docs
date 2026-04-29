class CreateLegacyRedirects < ActiveRecord::Migration[8.1]
  def change
    create_table :legacy_redirects do |t|
      t.references :package_version, null: false, foreign_key: true, index: false
      t.string :old_path, null: false
      t.references :entity_version, null: false, foreign_key: true

      t.timestamps
    end

    add_index :legacy_redirects, [:package_version_id, :old_path], unique: true
  end
end
