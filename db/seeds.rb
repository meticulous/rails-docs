# Idempotent dev seed. Creates the canonical Source row, then loads a small
# bundled JSONL (jbuilder v2.13.0 — ~300 records) so a fresh checkout has
# real entity data to render. For a full Rails ingest, see script/backfill.

source = Source.find_or_create_by!(slug: "rails") do |s|
  s.display_name = "Ruby on Rails"
  s.github_repo = "rails/rails"
  s.default_branch = "main"
end
puts "Seeded source: #{source.slug}"

sample_jsonl = Rails.root.join("db/seeds/sample.jsonl")
already_loaded = PackageVersion.joins(:source).where(sources: { slug: "jbuilder" }).exists?

if sample_jsonl.exist? && !already_loaded
  puts "Loading sample JSONL (jbuilder v2.13.0)…"
  File.open(sample_jsonl, "r:UTF-8") { |io| Loader.new(io).import! }
  puts "  → loaded #{PackageVersion.joins(:source).where(sources: { slug: 'jbuilder' }).first&.entity_versions&.count} entity_versions"
end

if PackageVersion.joins(:source).where(sources: { slug: "rails" }).where.not(ingested_at: nil).none?
  puts <<~HINT

    No Rails versions ingested yet (the seed only loads a small jbuilder sample).
    To populate the rails docs DB:

      script/backfill v8.1.2 8001002

    The script worktrees the tag in /tmp/, runs the rails_docs_ingester
    gem against it (~10 seconds), then loads the JSONL into Postgres
    (~1 minute). For other Foundation-maintained gems:

      script/ingest_gem turbo-rails 2.0.16 hotwired/turbo-rails app lib

  HINT
end
