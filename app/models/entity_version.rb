class EntityVersion < ApplicationRecord
  VISIBILITIES = %w[public protected private].freeze

  belongs_to :entity_identity
  belongs_to :package_version
  belongs_to :framework, optional: true

  has_one :method_version, dependent: :destroy
  has_one :class_version, dependent: :destroy
  has_one :constant_version, dependent: :destroy
  has_one :attribute_version, dependent: :destroy
  has_many :method_params, -> { order(:position) }, dependent: :destroy

  validates :visibility, inclusion: { in: VISIBILITIES }
  validates :entity_identity_id, uniqueness: { scope: :package_version_id }

  delegate :name, :fqn, :kind, :scope, to: :entity_identity
end
