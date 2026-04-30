class MakeEntityIdentitiesUniqueTreatNullsAsEqual < ActiveRecord::Migration[8.1]
  def change
    remove_index :entity_identities, name: "idx_entity_identities_unique"
    add_index :entity_identities,
              [ :source_id, :fqn, :kind, :scope ],
              unique: true,
              nulls_not_distinct: true,
              name: "idx_entity_identities_unique"
  end
end
