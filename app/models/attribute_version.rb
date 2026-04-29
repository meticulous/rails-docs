class AttributeVersion < ApplicationRecord
  RW_VALUES = %w[R W RW].freeze

  belongs_to :entity_version

  validates :rw, inclusion: { in: RW_VALUES }
  validates :entity_version_id, uniqueness: true
end
