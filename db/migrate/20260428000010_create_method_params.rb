class CreateMethodParams < ActiveRecord::Migration[8.1]
  def change
    create_table :method_params do |t|
      t.references :entity_version, null: false, foreign_key: true, index: false
      t.integer :position, null: false
      t.string :name, null: false
      t.string :kind, null: false
      t.text :default_expr
      t.text :doc

      t.timestamps
    end

    add_index :method_params, [ :entity_version_id, :position ], unique: true
  end
end
