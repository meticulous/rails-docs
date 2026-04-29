class ClassVersion < ApplicationRecord
  belongs_to :entity_version
  belongs_to :superclass_identity, class_name: "EntityIdentity", optional: true

  validates :entity_version_id, uniqueness: true
end
