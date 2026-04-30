class InheritanceEdge < ApplicationRecord
  RELATIONS = %w[superclass include extend prepend].freeze

  belongs_to :package_version
  belongs_to :child_identity, class_name: "EntityIdentity"
  belongs_to :ancestor_identity, class_name: "EntityIdentity"

  validates :relation, inclusion: { in: RELATIONS }
  validates :child_identity_id,
            uniqueness: { scope: [ :package_version_id, :ancestor_identity_id, :relation ] }
end
