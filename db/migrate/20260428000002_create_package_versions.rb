class CreatePackageVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :package_versions do |t|
      t.references :source, null: false, foreign_key: true, index: false
      t.string :channel, null: false
      t.integer :major
      t.integer :minor
      t.integer :patch
      t.string :prerelease
      t.string :release_series
      t.date :released_on
      t.string :git_ref, null: false
      t.string :git_sha, null: false
      t.datetime :ingested_at
      t.string :ingest_status, null: false, default: "pending"
      t.text :ingest_log
      t.bigint :ord, null: false

      t.timestamps
    end

    add_index :package_versions, [:source_id, :channel], unique: true
    add_index :package_versions, [:release_series, :ord]
  end
end
