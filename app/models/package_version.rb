class PackageVersion < ApplicationRecord
  enum :ingest_status,
       { pending: "pending", running: "running", ok: "ok", failed: "failed" },
       default: "pending",
       validate: true

  belongs_to :source

  has_many :entity_versions, dependent: :destroy
  has_many :inheritance_edges, dependent: :destroy
  has_many :inheritance_closures,
           foreign_key: :package_version_id,
           dependent: :destroy,
           inverse_of: :package_version
  has_many :legacy_redirects, dependent: :destroy
  has_many :first_seen_identities,
           class_name: "EntityIdentity",
           foreign_key: :first_seen_version_id,
           inverse_of: :first_seen_version,
           dependent: :nullify
  has_many :last_seen_identities,
           class_name: "EntityIdentity",
           foreign_key: :last_seen_version_id,
           inverse_of: :last_seen_version,
           dependent: :nullify

  validates :channel, presence: true, uniqueness: { scope: :source_id }
  validates :git_ref, :git_sha, :ord, presence: true

  # Highest-ord ingested release that isn't a prerelease. Used as the
  # default "current" view for canonical URLs and unscoped search.
  def self.current_stable
    where.not(ingested_at: nil).where(prerelease: [nil, ""]).order(ord: :desc).first
  end
end
