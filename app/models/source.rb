class Source < ApplicationRecord
  has_many :package_versions, dependent: :destroy
  has_many :frameworks, dependent: :destroy
  has_many :entity_identities, dependent: :destroy

  validates :slug, presence: true, uniqueness: true
  validates :display_name, :github_repo, presence: true
end
