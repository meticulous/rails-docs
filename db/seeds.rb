# Idempotent dev seed. Creates the canonical Source row so the schema isn't
# empty, then prints a hint on how to ingest a real Rails version. Real
# entity data comes from the ingester pipeline, not seeds — running the
# full ingester here would couple `db:seed` to a checked-out rails/rails
# tree and a slow process.

source = Source.find_or_create_by!(slug: "rails") do |s|
  s.display_name = "Ruby on Rails"
  s.github_repo = "rails/rails"
  s.default_branch = "main"
end

puts "Seeded source: #{source.slug}"

if PackageVersion.where(source: source).where.not(ingested_at: nil).none?
  puts <<~HINT

    No Rails versions ingested yet. To populate the docs DB:

      script/backfill v8.1.2 8001002

    The script worktrees the tag in /tmp/, runs the rails_docs_ingester
    gem against it (~10 seconds), then loads the JSONL into Postgres
    (~1 minute). See script/backfill --help (or read its source) for the
    full version → ord convention.

  HINT
end
