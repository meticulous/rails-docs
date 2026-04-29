class ConstantVersion < ApplicationRecord
  belongs_to :entity_version

  validates :entity_version_id, uniqueness: true
end
