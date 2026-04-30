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

  # GitHub permalink to the source span. Returns nil if RDoc didn't capture
  # a file/line for this entity (rare but happens for some ghost methods).
  def github_source_url
    return nil unless source_path.present? && source_line_start.present?
    line = "#L#{source_line_start}"
    line += "-L#{source_line_end}" if source_line_end.present?
    "https://github.com/#{entity_identity.source.github_repo}/blob/#{package_version.git_ref}/#{source_path}#{line}"
  end

  def github_edit_url
    return nil unless source_path.present?
    "https://github.com/#{entity_identity.source.github_repo}/edit/#{package_version.git_ref}/#{source_path}"
  end

  # GitHub code-search URL scoped to the source's owning org. Useful as a
  # "find usages" link for methods — clicking lands on real call sites in
  # the broader codebase. Static analysis would do better, but this is
  # cheap and works today.
  def github_search_url
    return nil if entity_identity.kind == "module" || entity_identity.kind == "class"
    org = entity_identity.source.github_repo.split("/").first
    query = "org:#{org} #{name}"
    "https://github.com/search?q=#{URI.encode_www_form_component(query)}&type=code"
  end
end
