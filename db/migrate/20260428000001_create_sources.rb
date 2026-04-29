class CreateSources < ActiveRecord::Migration[8.1]
  def change
    create_table :sources do |t|
      t.string :slug, null: false
      t.string :display_name, null: false
      t.string :github_repo, null: false
      t.string :default_branch, null: false, default: "main"

      t.timestamps
    end

    add_index :sources, :slug, unique: true
  end
end
