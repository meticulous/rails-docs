class EntityIdentity < ApplicationRecord
  KINDS = %w[module class method constant attribute].freeze
  SCOPES = %w[instance singleton].freeze

  belongs_to :source
  belongs_to :framework, optional: true
  belongs_to :first_seen_version, class_name: "PackageVersion", optional: true
  belongs_to :last_seen_version, class_name: "PackageVersion", optional: true

  has_many :entity_versions, dependent: :destroy

  validates :fqn, :name, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :scope, inclusion: { in: SCOPES }, allow_nil: true
  validates :fqn, uniqueness: { scope: [:source_id, :kind, :scope] }
end
