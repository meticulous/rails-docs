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

  def url_path
    self.class.fqn_to_url_path(fqn)
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
