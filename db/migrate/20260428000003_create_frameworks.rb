class CreateFrameworks < ActiveRecord::Migration[8.1]
  def change
    create_table :frameworks do |t|
      t.references :source, null: false, foreign_key: true, index: false
      t.string :slug, null: false
      t.string :display_name, null: false

      t.timestamps
    end

    add_index :frameworks, [ :source_id, :slug ], unique: true
  end
end
