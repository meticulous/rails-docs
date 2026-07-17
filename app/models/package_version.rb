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

  # Enforces the latest-patch-per-series policy after an ingest: 8.1.3
  # supersedes 8.1.2, 6.0.6.1 supersedes 6.0.6. Destroys every older
  # patch of this version's series (their per-version rows cascade via
  # the dependent declarations above), then deletes identities left with
  # no versions at all and repairs the first/last-seen pointers the
  # removal nullified. Returns the removed versions.
  def prune_superseded_patches!
    return [] if channel == "edge"

    mine = Gem::Version.new(channel)
    superseded = source.package_versions.where.not(id: id).where.not(channel: "edge").select do |pv|
      series_of(pv.channel) == series_of(channel) && Gem::Version.new(pv.channel) < mine
    end
    return [] if superseded.empty?

    superseded.each(&:destroy)
    destroy_orphaned_identities
    repair_seen_pointers
    superseded
  end

  # Highest-ord ingested release that isn't a prerelease. Used as the
  # default "current" view for canonical URLs and unscoped search. With
  # multiple Source rows ingested, this returns the highest-ord stable
  # across ALL sources — useful for "the most recent thing we know" but
  # the wrong default for cross-source search; use Source#current_stable
  # per-source.
  def self.current_stable
    where.not(ingested_at: nil).where(prerelease: [ nil, "" ]).order(ord: :desc).first
  end

  # The current_stable PackageVersion for each Source — returned as an
  # array. Search uses this to scope cross-source queries to "the latest
  # of every gem" without surfacing duplicates from older versions.
  # Postgres DISTINCT ON keeps the highest-ord row per source_id without
  # round-tripping every stable row to Ruby.
  def self.current_stable_for_each_source
    where.not(ingested_at: nil)
         .where(prerelease: [ nil, "" ])
         .select("DISTINCT ON (source_id) package_versions.*")
         .order(:source_id, ord: :desc)
  end

  private

  # "8.1.3" and "8.1.2" share the series ["8", "1"]; "6.0.6.1" and
  # "6.0.6" share ["6", "0"]. Derived from the channel rather than the
  # release_series column so pruning can't miss a row where the ingester
  # left the column blank.
  def series_of(version_channel)
    version_channel.split(".").first(2)
  end

  # Identities whose every version was pruned would ghost through nav
  # trees and crossref candidate lookups — remove them outright. Some
  # identities legitimately carry no entity_versions at all: reference
  # targets like a superclass that never had docs of its own, still
  # pointed at by class_versions/inheritance rows of surviving versions.
  # The FK rescue keeps those.
  def destroy_orphaned_identities
    source.entity_identities.where.missing(:entity_versions).find_each do |identity|
      identity.destroy
    rescue ActiveRecord::InvalidForeignKey
      # Referenced-only identity — keep it.
    end
  end

  # The dependent: :nullify on first/last_seen_identities blanks pointers
  # at pruned versions; recompute them from the versions that remain
  # (same ord-based semantics as Loader#refresh_first_last_seen_versions).
  def repair_seen_pointers
    ApplicationRecord.connection.execute(ApplicationRecord.sanitize_sql([ <<~SQL, source_id ]))
      UPDATE entity_identities ei
      SET first_seen_version_id = agg.first_id,
          last_seen_version_id = agg.last_id
      FROM (
        SELECT ev.entity_identity_id AS identity_id,
               (ARRAY_AGG(ev.package_version_id ORDER BY pv.ord ASC))[1] AS first_id,
               (ARRAY_AGG(ev.package_version_id ORDER BY pv.ord DESC))[1] AS last_id
        FROM entity_versions ev
        JOIN package_versions pv ON pv.id = ev.package_version_id
        JOIN entity_identities i ON i.id = ev.entity_identity_id
        WHERE i.source_id = ?
        GROUP BY ev.entity_identity_id
      ) agg
      WHERE ei.id = agg.identity_id
        AND (ei.first_seen_version_id IS DISTINCT FROM agg.first_id
             OR ei.last_seen_version_id IS DISTINCT FROM agg.last_id)
    SQL
  end
end
