class EntityIdentity < ApplicationRecord
  KINDS = %w[module class method constant attribute].freeze
  SCOPES = %w[instance singleton].freeze

  belongs_to :source
  belongs_to :framework, optional: true
  belongs_to :first_seen_version, class_name: "PackageVersion", optional: true
  belongs_to :last_seen_version, class_name: "PackageVersion", optional: true

  has_many :entity_versions, dependent: :destroy

  # PackageVersions in which this identity has an entity_version, oldest first
  # by package_versions.ord. Used by the "Available in" strip on entity pages.
  has_many :available_versions,
           through: :entity_versions,
           source: :package_version,
           class_name: "PackageVersion"

  validates :fqn, :name, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :scope, inclusion: { in: SCOPES }, allow_nil: true
  validates :fqn, uniqueness: { scope: [ :source_id, :kind, :scope ] }

  # Maps each package_version_id in which this identity exists to an md5
  # digest of exactly the columns the diff page renders — doc_markdown and
  # signature_text (DiffPresenter#doc_diff/#signature_diff) — so a
  # "changed" tag on a version picker always means the diff page will
  # actually show a difference. One round-trip over entity_versions —
  # there is exactly one row per package_version (unique index
  # idx_entity_versions_unique), so no GROUP BY is needed. Nil columns
  # are coalesced to '' and joined with chr(31) (unit separator, never
  # present in doc text) so field boundaries can't collide.
  def content_digest_by_version
    @content_digest_by_version ||=
      entity_versions
        .pluck(
          :package_version_id,
          Arel.sql(<<~SQL.squish)
            md5(concat_ws(chr(31),
              coalesce(doc_markdown, ''),
              coalesce(signature_text, '')))
          SQL
        )
        .to_h
  end

  # The set of package_version_ids whose content differs from the given
  # package_version's. A version with no entity_version (no digest) or an
  # identical digest is not "changed" and so is excluded.
  def changed_version_ids(relative_to:)
    digests = content_digest_by_version
    baseline = digests[relative_to.id]
    digests.filter_map { |pv_id, digest| pv_id if digest != baseline }.to_set
  end

  def url_path
    self.class.fqn_to_url_path(fqn)
  end

  # The path for this entity under a version prefix — the single source of
  # truth for URL construction. EntityPathHelper#entity_url_path and
  # CrossrefLinker both delegate here so prose-generated links can never
  # drift from the app's canonical routes. Methods and attributes get
  # their name slug-encoded (?, !, = and operators aren't URL-safe);
  # singleton methods carry the .class suffix that disambiguates them
  # from same-named instance methods.
  def entity_url_path
    case kind
    when "method"
      slug = MethodSlug.encode(name)
      slug = "#{slug}.class" if scope == "singleton"
      "#{self.class.fqn_to_url_path(parent_fqn)}/#{slug}"
    when "attribute"
      "#{self.class.fqn_to_url_path(parent_fqn)}/#{MethodSlug.encode(name)}"
    else
      url_path
    end
  end

  # ActiveRecord::Persistence -> [["ActiveRecord", "active_record"], ["Persistence", "active_record/persistence"]]
  def breadcrumb_segments
    self.class.breadcrumb_segments_for(fqn)
  end

  def self.fqn_to_url_path(fqn)
    fqn.to_s.split("::").map(&:underscore).join("/")
  end

  def self.breadcrumb_segments_for(fqn)
    parts = fqn.to_s.split("::")
    parts.each_with_index.map do |part, i|
      [ part, parts[0..i].map(&:underscore).join("/") ]
    end
  end
end
