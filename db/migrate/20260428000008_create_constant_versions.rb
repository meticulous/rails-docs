class CreateConstantVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :constant_versions do |t|
      t.references :entity_version, null: false, foreign_key: true, index: { unique: true }
      t.text :value_expr

      t.timestamps
    end
  end
end
