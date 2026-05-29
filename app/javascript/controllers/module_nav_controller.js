import { Controller } from "@hotwired/stimulus"

// Drives the persistent left module-nav, which is a collapsible
// namespace tree grouped by framework. Three jobs:
//
//   1. toggleNode  — expand/collapse a single tree node's children.
//   2. filter      — substring-match across the whole tree as the user
//                    types, revealing matches plus their ancestors.
//   3. active trail — on connect, expand the branch leading to the
//                    current page and highlight it + its upstream
//                    namespace ancestors. Done in JS (not server-
//                    rendered) so the fragment cache stays per-version.
//
// Each <li class="module-nav__node"> carries data-fqn (lowercased FQN).
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

  // Framework groups: open only the active framework by default.
  applyDefaultExpansion() {
    this.groupTargets.forEach(group => {
      group.open = group.dataset.frameworkSlug === this.activeFrameworkValue
    })
  }

  // Expand/collapse one node's immediate children.
  toggleNode(event) {
    const node = event.currentTarget.closest(".module-nav__node")
    const children = node.querySelector(":scope > .module-nav__children")
    if (!children) return
    const show = children.hidden
    children.hidden = !show
    event.currentTarget.setAttribute("aria-expanded", show ? "true" : "false")
  }

  markActiveTrail() {
    const active = (this.activeFqnValue || "").toLowerCase()
    if (!active) return
    const upstream = new Set(this.upstreamFqnsValue.map(s => s.toLowerCase()))

    let activeEl = null
    this.element.querySelectorAll(".module-nav__node").forEach(node => {
      const fqn = node.dataset.fqn
      if (fqn === active) {
        node.classList.add("module-nav__node--active")
        activeEl = node
      } else if (upstream.has(fqn)) {
        node.classList.add("module-nav__node--upstream")
      }
    })

    if (!activeEl) return

    // Walk up, revealing each ancestor's children list and flipping the
    // owning toggle, and open the enclosing framework <details>.
    let el = activeEl.parentElement
    while (el && this.element.contains(el)) {
      if (el.classList?.contains("module-nav__children")) {
        el.hidden = false
        const owner = el.closest(".module-nav__node")
        owner?.querySelector(":scope > .module-nav__row > .module-nav__toggle")
          ?.setAttribute("aria-expanded", "true")
      }
      if (el.tagName === "DETAILS") el.open = true
      el = el.parentElement
    }

    // Also reveal the active node's own children so the user sees what's
    // beneath the page they're on.
    const ownChildren = activeEl.querySelector(":scope > .module-nav__children")
    if (ownChildren) {
      ownChildren.hidden = false
      activeEl.querySelector(":scope > .module-nav__row > .module-nav__toggle")
        ?.setAttribute("aria-expanded", "true")
    }

    activeEl.scrollIntoView({ block: "nearest", behavior: "instant" })
  }

  filter() {
    const query = this.filterTarget.value.trim().toLowerCase()
    const filtering = query.length > 0
    let anyVisible = false

    this.groupTargets.forEach(group => {
      let groupVisible = false
      group.querySelectorAll(":scope > .module-nav__tree > .module-nav__node").forEach(node => {
        if (this.filterNode(node, query, filtering)) groupVisible = true
      })
      group.hidden = filtering && !groupVisible
      if (filtering) group.open = groupVisible
      if (groupVisible) anyVisible = true
    })

    if (!filtering) {
      this.applyDefaultExpansion()
      this.markActiveTrail()
    }
    this.emptyTarget.hidden = anyVisible || !filtering
  }

  // Post-order: a node is visible if it matches or any descendant does.
  // While filtering we expand branches that contain a match.
  filterNode(node, query, filtering) {
    const selfMatch = !filtering || node.dataset.fqn.includes(query)
    const childrenUl = node.querySelector(":scope > .module-nav__children")

    let childVisible = false
    if (childrenUl) {
      childrenUl.querySelectorAll(":scope > .module-nav__node").forEach(child => {
        if (this.filterNode(child, query, filtering)) childVisible = true
      })
    }

    const visible = selfMatch || childVisible
    node.hidden = !visible

    if (childrenUl) {
      if (filtering) {
        childrenUl.hidden = !childVisible
        node.querySelector(":scope > .module-nav__row > .module-nav__toggle")
          ?.setAttribute("aria-expanded", childVisible ? "true" : "false")
      } else {
        // Reset to collapsed when the filter clears; active-trail re-expands.
        childrenUl.hidden = true
        node.querySelector(":scope > .module-nav__row > .module-nav__toggle")
          ?.setAttribute("aria-expanded", "false")
      }
    }

    return visible
  }
}
