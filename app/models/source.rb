class Source < ApplicationRecord
  has_many :package_versions, dependent: :destroy
  has_many :frameworks, dependent: :destroy
  has_many :entity_identities, dependent: :destroy

  validates :slug, presence: true, uniqueness: true
  validates :display_name, :github_repo, presence: true

  # One-line, self-description-matching blurbs for the ecosystem page.
  # Presentation copy, not domain data, so it lives here as a constant
  # map rather than a column. Unknown/future slugs return nil so the
  # view can skip the description line gracefully.
  DESCRIPTIONS = {
    "turbo-rails" => "Hotwire's page acceleration framework — SPA-speed navigation and partial updates without writing JavaScript.",
    "stimulus-rails" => "Hotwire's modest JavaScript framework for adding behavior to HTML you already have.",
    "importmap-rails" => "Deliver JavaScript modules to browsers via ESM without transpiling or bundling.",
    "propshaft" => "The Rails asset pipeline for compiling and delivering static assets.",
    "kamal" => "Deploy web apps anywhere — zero-downtime container deployment without complex infrastructure.",
    "solid_queue" => "A DB-backed Active Job backend for handling background jobs.",
    "solid_cache" => "A DB-backed Rails cache store, using your database to keep more data cached.",
    "solid_cable" => "A DB-backed Action Cable adapter for WebSocket connections.",
    "globalid" => "App-wide URIs for your models that let objects reference each other across the app.",
    "jbuilder" => "A simple DSL for declaring JSON structures in templates."
  }.freeze

  # One-line self-description for the ecosystem page, or nil if this
  # source has no blurb yet (e.g. rails itself, or a newly added gem).
  def description
    DESCRIPTIONS[slug]
  end

  # The highest-ord ingested non-prerelease PackageVersion for this
  # source. Used as the canonical "current" version for cross-source
  # links and per-source home/feed surfaces.
  def current_stable
    package_versions
      .where.not(ingested_at: nil)
      .where(prerelease: [ nil, "" ])
      .order(ord: :desc)
      .first
  end
end
