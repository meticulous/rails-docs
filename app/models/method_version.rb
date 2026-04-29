class MethodVersion < ApplicationRecord
  belongs_to :entity_version
  belongs_to :aliased, class_name: "EntityIdentity", optional: true

  validates :entity_version_id, uniqueness: true
end
