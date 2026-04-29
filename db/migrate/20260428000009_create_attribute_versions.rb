class CreateAttributeVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :attribute_versions do |t|
      t.references :entity_version, null: false, foreign_key: true, index: { unique: true }
      t.string :rw, null: false

      t.timestamps
    end
  end
end
