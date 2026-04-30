# Design inventory — UI surfaces to evaluate

Reference document for the upcoming UX/flow/UI refactor pass. Every code-level
v1+v2 plan item is shipped; this captures every surface that needs design
attention so the refactor can be planned against a real list.

Generated 2026-04-30 from the live state of meticulous/rails-docs.

---

## Page-level surfaces (destinations)

### Tier 1 — primary surfaces

| Surface | URL | Notes |
|---|---|---|
| **Class / module entity page** | `/v8.1.2/active_record/base` | The page users land on most often. Shows ~65 ancestors + 191 inherited methods on AR::Base — density management is the big design problem. |
| **Method entity page** | `/v8.1.2/active_record/persistence/save` | Shorter than class pages but high-traffic. Signature, params, source toggle, "Defined in", source link, alias. |
| **Search results** | `/search?q=has_many` | Facet sidebar + results column. Today's source-attribution is unclear when results mix rails + ecosystem. |
| **Home** | `/` | Landing surface; heavily SEO'd. Currently undernourished. |
| **Version overview** | `/v8.1.2` | Framework grid for that Rails version. |

### Tier 2 — secondary surfaces

| Surface | URL | Notes |
|---|---|---|
| **Ecosystem index** | `/ecosystem` | Cards for each non-rails source (turbo-rails, solid_queue, etc.). |
| **Diff page** | `/v8.1.2/active_record/persistence/save/-/diff/v7.1.6` | Side-by-side or unified diff. Today: vertical line list. |
| **Missing entity page** | `entities/missing.html.erb` | "Not present in v8.1.2; first/last seen in vX." |
| **Constant / attribute pages** | `/v8.1.2/.../FOO` | Currently reuse class layout — could use a leaner layout. |
| **Search "no results"** | `/search?q=qzx` | "Did you mean…" branch with fuzzy matches. |

### Tier 3 — utilitarian / system

| Surface | URL | Notes |
|---|---|---|
| 404 / RecordNotFound | various | Currently Rails default. |
| Generic error | various | Rails default. |
| Atom feed | `/feeds/activerecord` | XML; rendered by feed readers, not in-browser. Probably fine as-is. |
| Sitemap | `/sitemap.xml` | XML; not user-facing. |
| OG image | `/v8.1.2/og/...svg` | Templated SVG; design tweaks would matter. |

---

## Components (atoms that recur)

### Header / footer

- **Site header**: brand link · search box · version chip · theme toggle. On non-rails sources we'd want a *source chip* somewhere.
- **Site footer**: minimal today ("API documentation for the Ruby on Rails framework"). Could carry GitHub links, "edit this page," last-updated.

### Entity-page chrome

- **Breadcrumbs** (`ActiveRecord :: Persistence#save`) — clickable, today rendered as inline list
- **Entity title block** — kind badge + name + version line + Available-in strip + Compare-with select + Since/Removed/Deprecated badges. Lots of stuff competing for the same vertical band.
- **Outline / TOC sidebar** — "On this page" with scroll-spy active state
- **"Defined in" source-link row** — file path · line · View on GitHub · Improve this page · Find usages on GitHub

### Lists & groups

- **Method list** (own + inherited) — currently a CSS grid of `# name` items. Compact and scannable but could carry more meta (visibility, deprecation, scope).
- **Method group `<details>`** (inherited methods by ancestor) — header row with "From X (count)", expandable
- **Includes/Extends/Prepends list** — flat list of module links
- **Constants / Attributes list** — currently small flat lists

### Method page details

- **Signature block** (`save(**options)`) — currently a plain `<pre>` block, brand-toned bg
- **Params definition list** — `<dl>` with kind badge (KEYREST, BLOCK, REQ, OPT)
- **Source `<details>`** — collapsed source code
- **"Aliased as / Alias for"** — small section
- **"Defined in <ParentClass>"** back-link

### Search & navigation

- **Search results card** — breadcrumb · linked FQN · kind badge · summary · meta line (version + framework). Source attribution is the gap.
- **Facet sidebar** — Source, Kind, Framework. Active chips, count display.
- **⌘K palette modal** — input · live result list · keyboard hints. Probably the most "designed" surface today.
- **Did you mean** — list under empty results

### Multi-source affordances (mostly missing)

- **Source chip in header** — shows "rails" / "turbo-rails" so the user knows which corpus they're in
- **Source switcher** — way to jump from `ActiveRecord::Base` to "what would I find in Turbo here"
- **Cross-source link styling** — `{{turbo:...}}` tokens render as inline `<code>` with link; should they look distinct from same-source links?

### Diff

- **Diff line** — added / removed / changed / unchanged. Currently colored span. Could be richer (split-view, syntax highlighting, expandable context).

### State indicators

- **Since / Removed / Deprecated badges** — pill chips in cyan / yellow / red
- **"Available in vX, vY"** chip strip — current version highlighted brand-red

---

## Cross-cutting design tokens

Already pulled from `rails/guides`:
- Brand red `#C81418`, full gray scale, dark-mode tokens
- `--radius: 8px`, system font stack

Still TBD:
- **Typography scale** — heading sizes, line heights, optical sizing for code
- **Spacing scale** — currently mixed em/rem with no rhythm
- **Icon set** — emoji used for theme toggle (☀ ☾ ◑); a real icon set (Lucide / Heroicons / custom?) for: anchor-copy, copy code, github, external-link, version-switcher arrow, search, ⌘K hint
- **Code typography** — mono stack OK, but no syntax highlighting yet (Rouge? Shiki at build?)
- **Shadows / elevation** — only used on the ⌘K modal; could apply to focused states, hover cards
- **Focus rings** — accessibility concern; brand red glow is consistent today but rough
- **Mobile breakpoints** — currently `768px` for the search facet collapse. Whole grid system for the entity-page two-column layout under mobile is undefined.

---

## Interaction patterns to think about

These aren't "designs" — they're behavior decisions:

1. **Theme toggle** — three-state cycle (light/dark/system) with persisted choice. Today a single icon; could be a labeled segmented control.
2. **⌘K vs. inline search** — they coexist. ⌘K opens palette; "/" focuses inline search. Should clicking the inline search box also open the palette? Or is the inline search a different mode (full results page on submit, vs. palette which navigates direct)?
3. **Outline scroll-spy** — works on class and method pages. Visual treatment is a left-border highlight; could be more.
4. **Anchor copy** — hover reveals `#`, click copies + flashes "copied". Is the `#` always visible on small screens?
5. **Inherited method foldout** — `<details>` defaults to open. Should remember user's preference per ancestor?
6. **Version dropdown** — changes URL on selection. What feedback during navigation?
7. **Compare-with dropdown** — same.
8. **Search facet selection** — page reloads with new URL params today. Could be Turbo Frame for partial update.
9. **Method list density** — grid is dense, hard to scan. Filters by visibility/scope? Alphabetical jump-bar?
10. **Mobile drawer for sidebar** — outline + facets + version switcher all fight for space on narrow screens.

---

## Open design questions (decision needed before sketching)

1. **Source-prefixed URL system: brand differentiation?** Should `/turbo-rails/...` carry a different accent color, a different brand tag, or be visually identical to `/v8.1.2/...` aside from the source chip?
2. **Search default scope.** When on a non-rails source, does search default to that source, or always cross-source with a prominent "this source" filter?
3. **Inherited methods density.** AR::Base shows 191 methods grouped by 65 ancestors. Apple Developer Docs collapses by default; we expand. Scroll fatigue is real — what's the v1 default?
4. **Per-method outline content.** Today: signature, doc, params, alias, source. Should we add "Used by" (v2) and "See also" (manual)?
5. **Diff layout.** Unified line diff (current) vs. side-by-side? GitHub does both; doc diffs read better unified.
6. **Mobile navigation pattern.** Hamburger? Slide-out drawer for outline? Sticky bottom bar?
7. **Code typography.** Plain mono now. Syntax highlighting decision: Rouge (server-side, free) vs. nothing.
8. **Empty / sparse states.** Module with no methods: what does the outline show? Class with no doc comment: how prominent is "no documentation comment"?
9. **Footer content.** Foundation-attributed? Edit-this-page repeated? Last-ingest timestamp?
10. **Print styles.** Engineers print API docs sometimes (PDF for offline, especially). Worth defining.

---

## Suggested order of design attack

If sketching in priority order:

1. **Typography + spacing scale** — propagates everywhere
2. **Class entity page** — sets the dense-content treatment
3. **Method entity page** — borrows from class but simpler
4. **Site header** (with source chip) — sets brand framing
5. **Home + ecosystem grid** — landing surfaces
6. **Search results + facets + ⌘K** — discovery
7. **Diff page** — important but less-trafficked
8. **404 / missing / empty states** — polish layer

---

## Out-of-scope for this pass (deferred)

- ViewComponent / Lookbook adoption — discussed and deferred; plain partials + presenters stay
- OG PNG fallback — SVG works for Slack/Mastodon/Discord; PNG only matters for Twitter/Facebook
- Inheritor refs via Prism static analysis — v2 feature, half-day work
- Comments / community notes — heavy moderation lift, defer to v2
- Typesense as accelerator — sponsorship-funded
