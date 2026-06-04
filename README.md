# rails-docs

Rails app that powers the [api.rubyonrails.org][api] redesign. Ingests every targeted Rails release — plus the official ecosystem gems — into Postgres and serves dynamic, versioned API documentation.

Replaces the static-site generation flow (sdoc → versioned tarballs) with a single Rails app: per-method URLs, inheritance aggregation (Apple Developer Docs–style), cross-version diffs, "available since / deprecated in" badges, real cross-version search, and a first-class machine-readable surface for AI agents.

## Status

Active development. Part of the api.rubyonrails.org redesign funded by the Rails Foundation; targeting [RailsWorld 2026][railsworld].

The v1 feature set is in place and the full dataset ingests and serves end to end — **11 sources, 80+ package versions, ~137K entity versions** (Rails 2.2 → 8.1 plus the official ecosystem gems). A working deployment runs via Dokku.

Still open: Foundation hosting decision, automated release ingestion (the webhook pipeline exists but isn't yet wired to rails/rails CI), and the broader UX/UI/flow pass.

## Stack

- Ruby 3.4, Rails 8.1
- Postgres only (no Redis); Solid Queue + Solid Cache
- Hotwire (Turbo + Stimulus), ERB, Propshaft, importmap-rails
- Vanilla Minitest (unit/integration) + Capybara system tests
- Vendor-neutral search behind a `SearchAdapter` interface — Postgres FTS today, Typesense/Algolia/Meilisearch as future accelerators
- Deploy via Kamal or Dokku (Dockerfile-based)

## Feature surface

- **Per-entity URLs** — `/v8.1.2/active_record/persistence/save`. Operator slugs round-trip (`#[]` → `-bracket`), singleton methods use a `.class` suffix, ALL_CAPS constants and acronym namespaces (`PostgreSQLAdapter`) resolve without an inflections table.
- **Inheritance aggregation** — inherited methods grouped by ancestor via a closure table refreshed at ingest; class-page render <100 ms p95 even for `ActiveRecord::Base`.
- **Namespace tree nav** — collapsible left rail grouped by framework, lazy-loaded (see _AI readability_ below).
- **Version diff** — `…/-/diff/v7.0` compares any two versions of an entity (signature- and doc-aware).
- **Since / Removed / Deprecated badges** and an "Available in" version strip on every entity page.
- **Public + private methods** — privates are ingested but separated into a collapsed section, deranked in search, and `noindex`'d.
- **Search** — Postgres FTS with kind-aware ranking (methods ×1.6, attrs ×1.4, constants ×1.2; deprecated ×0.4; private ×0.5) and `pg_trgm` "did you mean" suggestions. ⌘K palette.
- **Ecosystem** — turbo-rails, stimulus-rails, kamal, the Solid trio, propshaft, importmap-rails, jbuilder, globalid, each multi-version, under `/<gem>/v<version>/…`.
- **Cross-source markdown tokens** in doc comments — `{{guide:slug}}` → guides.rubyonrails.org, `{{turbo:Turbo::StreamsChannel}}` → that entity in turbo-rails' current stable.
- **SEO** — schema.org `TechArticle` JSON-LD, canonical-to-current-stable, per-version sitemaps, OG images, 301s from legacy sdoc URLs, Atom "what's new" feeds per framework.
- **Static export + Dash docset** (`app/exporters/`, `rake export`).
- **Ops** — `/up` (liveness) and `/health` (DB + search + ingest-freshness) probes, CSP, rate-limited search/webhook endpoints, branded in-app error pages.

## AI / LLM readability

Content pages are built so an AI crawler or agent gets the documentation, not the chrome. A method page is **~5 KB gzipped** (the 1,500-node nav is not inline).

- **Markdown per entity** — append `.md` to any entity URL, or send `Accept: text/markdown`:
  ```
  GET /v8.1.2/active_record/persistence/save.md   →  text/markdown
  ```
  Returns a compact doc (title, kind/framework/version, signature, documentation, "Available in", source link) drawn from the stored `doc_markdown` — no HTML, no JS. See `EntityMarkdown`.
- **`/llms.txt`** — the emerging convention; dynamically lists the `.md` URL scheme, the framework index for current stable, and the sitemap.
- **Content-first HTML** — the persistent left navigation is lazy-loaded into a `data-turbo-permanent` Turbo Frame (`NavController`, `/_nav`), so it loads once per session and never ships inline on content pages. A no-JS client or crawler fetches a clean, content-dominant document; the active-row highlight rides in `<meta name="nav-*">` tags applied client-side.
- **Structured data** — schema.org `TechArticle` JSON-LD on every public entity page (suppressed + `noindex` on private methods).

## URL scheme

```
/v<VERSION>/<framework>/<path>                  class or module
/v<VERSION>/<framework>/<path>/<method>         instance method
/v<VERSION>/<framework>/<path>/<method>.class   class (singleton) method
/v<VERSION>/<framework>/<path>/-/diff/<other>   version diff
/<gem>/v<VERSION>/<path>                         ecosystem gem
<any-entity-url>.md                             machine-readable Markdown
```

Version-less URLs (e.g. `/active_record/persistence/save`) redirect to current stable.

## Development

```bash
bin/setup            # installs deps, creates + seeds the DB
bin/dev              # or bin/rails server → http://localhost:3000
bin/rails test       # unit + integration
bin/rails test:all   # + Capybara system tests
bin/rubocop
bin/brakeman
```

## Data: ingest & backfill

This app loads JSONL produced by the companion [`rails_docs_ingester`][ingester] gem (RDoc walks a checked-out source tree → JSONL → `bin/load` → Postgres). The split keeps schema iteration cheap (re-run the loader in minutes, not RDoc over every version in hours).

```bash
bin/load path/to/8.1.2.jsonl          # load one JSONL dump

script/backfill v8.1.2 8001002        # worktree a Rails tag, ingest, load
script/refresh_all                    # re-run the full Rails version matrix
script/ingest_gem turbo-rails 2.0.23 hotwired/turbo-rails lib app
script/refresh_ecosystem              # re-run the full ecosystem gem matrix
```

`IngestPackageVersionJob` + `WebhooksController` provide an HMAC-verified, Solid Queue–backed webhook path for automated release ingestion (POST `/webhooks/ingest`); wiring it to rails/rails CI is pending.

## Deployment

Dockerfile-based; deployable with Kamal (`config/deploy.yml`) or Dokku. Postgres is the only required service; cache and queue can share the primary database. Set `RAILS_MASTER_KEY`, `RAILS_ALLOWED_HOSTS`, and `INGEST_WEBHOOK_SECRET`.

## Companion repo

[`meticulous/rails_docs_ingester`][ingester] — the RDoc-based extractor that produces the JSONL this app loads.

[api]: https://api.rubyonrails.org
[railsworld]: https://rubyonrails.org/2026/
[ingester]: https://github.com/meticulous/rails_docs_ingester
