class InheritanceClosure < ApplicationRecord
  self.primary_key = [:package_version_id, :descendant_identity_id, :ancestor_identity_id]

  belongs_to :package_version
  belongs_to :descendant_identity, class_name: "EntityIdentity"
  belongs_to :ancestor_identity, class_name: "EntityIdentity"
end
