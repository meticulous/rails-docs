class Framework < ApplicationRecord
  belongs_to :source

  has_many :entity_identities, dependent: :nullify
  has_many :entity_versions, dependent: :nullify

  validates :slug, presence: true, uniqueness: { scope: :source_id }
  validates :display_name, presence: true
end
