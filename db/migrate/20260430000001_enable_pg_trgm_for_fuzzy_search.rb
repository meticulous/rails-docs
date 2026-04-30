class EnablePgTrgmForFuzzySearch < ActiveRecord::Migration[8.1]
  def up
    enable_extension "pg_trgm"
    execute <<~SQL
      CREATE INDEX IF NOT EXISTS idx_entity_identities_name_trgm
      ON entity_identities USING gin (name gin_trgm_ops)
    SQL
  end

  def down
    execute "DROP INDEX IF EXISTS idx_entity_identities_name_trgm"
    disable_extension "pg_trgm"
  end
end
