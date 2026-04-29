class MethodParam < ApplicationRecord
  KINDS = %w[req opt rest keyreq key keyrest block].freeze

  belongs_to :entity_version

  validates :name, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :position,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            uniqueness: { scope: :entity_version_id }
end
