# rails-docs

Rails app that powers [api.rubyonrails.org][api]. Ingests every targeted Rails release into Postgres and serves dynamic, versioned API documentation.

Replaces the static-site generation flow (sdoc → versioned tarballs) with a single Rails app that supports per-method URLs, inheritance aggregation (Apple Developer Docs–style), version diff, "available since / deprecated in" badges, and real cross-version search.

## Status

Pre-alpha. Part of the api.rubyonrails.org redesign funded by the Rails Foundation. Targeting [RailsWorld 2026][railsworld] (September, Austin).

## Stack

- Ruby 3.4, Rails 8.1
- Postgres only (no Redis in v1)
- Hotwire (Turbo + Stimulus), ERB, importmap-rails
- Vanilla Minitest for unit/integration/system tests
- Playwright for end-to-end click coverage
- Vendor-neutral search behind a `SearchAdapter` interface — Postgres FTS in v1, Typesense/Algolia/Meilisearch as future accelerators
- Static export pipeline for offline UX + Dash docsets

## Companion repo

[`meticulous/rails_docs_ingester`][ingester] is the RDoc-based extractor that produces JSONL from a checked-out Rails source tree. This app loads that JSONL into its database.

## Development

```bash
bin/setup            # installs deps, creates DB
bin/rails server     # http://localhost:3000
bin/rails test       # unit + integration + system
bin/rails test:all   # includes Playwright e2e (once wired up)
```

## Plan

Architecture, schema, milestones, and v1/v2/v3 phasing are documented in the project plan file (kept outside the repo).

[api]: https://api.rubyonrails.org
[railsworld]: https://rubyonrails.org/2026/
[ingester]: https://github.com/meticulous/rails_docs_ingester
