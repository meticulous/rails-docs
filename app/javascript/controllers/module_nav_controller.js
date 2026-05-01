import { Controller } from "@hotwired/stimulus"

// Filter the persistent left module-nav as the user types AND mark
// the active row (where the user is) plus its upstream FQN trail.
// Decoration happens in JS (not server-rendered) so the partial's
// fragment cache stays per-version, not per-page.
//
// Each <li> carries data-fqn (lowercased FQN) so we do a substring
// match without re-querying the DOM. While filtering, every framework
// <details> auto-expands so matches in collapsed groups are still
// visible; when the filter clears, groups restore to the default
// (only the active-framework group open).
export default class extends Controller {
  static targets = ["filter", "list", "empty", "group"]
  static values = {
    activeFramework: String,
    activeFqn: String,
    upstreamFqns: { type: Array, default: [] },
  }

  connect() {
    this.applyDefaultExpansion()
    this.markActiveTrail()
  }

  applyDefaultExpansion() {
    this.groupTargets.forEach(group => {
      group.open = group.dataset.frameworkSlug === this.activeFrameworkValue
    })
  }

  markActiveTrail() {
    const active = this.activeFqnValue
    if (!active) return
    const upstream = new Set(this.upstreamFqnsValue)

    // Match the underlying FQN, not the lowercased slug — a single
    // pass over every nav item.
    let activeEl = null
    this.element.querySelectorAll(".module-nav__item").forEach(item => {
      const fqn = item.querySelector(".module-nav__link")?.title
      if (!fqn) return
      if (fqn === active) {
        item.classList.add("module-nav__item--active")
        activeEl = item
      } else if (upstream.has(fqn)) {
        item.classList.add("module-nav__item--upstream")
      }
    })

    if (activeEl) {
      // Scroll the active row into view so a deep link doesn't leave
      // it off-screen below the filter input.
      activeEl.scrollIntoView({ block: "nearest", behavior: "instant" })
    }
  }

  filter() {
    const query = this.filterTarget.value.trim().toLowerCase()
    const filtering = query.length > 0
    let visibleTotal = 0

    this.groupTargets.forEach(group => {
      let visibleInGroup = 0
      group.querySelectorAll(".module-nav__item").forEach(item => {
        const matches = !filtering || item.dataset.fqn.includes(query)
        item.hidden = !matches
        if (matches) visibleInGroup++
      })
      group.hidden = filtering && visibleInGroup === 0
      if (filtering) {
        group.open = visibleInGroup > 0
      }
      visibleTotal += visibleInGroup
    })

    if (!filtering) this.applyDefaultExpansion()
    this.emptyTarget.hidden = visibleTotal > 0
  }
}
