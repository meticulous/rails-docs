class Source < ApplicationRecord
  has_many :package_versions, dependent: :destroy
  has_many :frameworks, dependent: :destroy
  has_many :entity_identities, dependent: :destroy

  validates :slug, presence: true, uniqueness: true
  validates :display_name, :github_repo, presence: true

  # The highest-ord ingested non-prerelease PackageVersion for this
  # source. Used as the canonical "current" version for cross-source
  # links and per-source home/feed surfaces.
  def current_stable
    package_versions
      .where.not(ingested_at: nil)
      .where(prerelease: [nil, ""])
      .order(ord: :desc)
      .first
  end
end
