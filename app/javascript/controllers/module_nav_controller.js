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
//
// The nav body is version-cached and shared across pages (it loads into
// a data-turbo-permanent frame once per session). The per-page active
// context therefore can't live in the cached HTML — it's read from
// <meta name="nav-*"> tags, which Turbo refreshes on each navigation.
// We re-decorate on turbo:load so the highlight follows the user as
// they click through the (persistent) nav.
export default class extends Controller {
  static targets = ["filter", "list", "empty", "group", "ecosystem", "status"]

  connect() {
    this.boundRefresh = this.refreshActive.bind(this)
    document.addEventListener("turbo:load", this.boundRefresh)
    this.applyDefaultExpansion()
    this.markActiveTrail()
    this.reconcileEcosystem()
  }

  disconnect() {
    document.removeEventListener("turbo:load", this.boundRefresh)
  }

  // Read per-page active context from the document's meta tags.
  get activeFqn() {
    return (this.metaContent("nav-active-fqn") || "").toLowerCase()
  }

  get activeFramework() {
    return this.metaContent("nav-active-framework") || ""
  }

  get upstreamFqns() {
    try {
      return JSON.parse(this.metaContent("nav-upstream-fqns") || "[]")
    } catch {
      return []
    }
  }

  metaContent(name) {
    return document.querySelector(`meta[name="${name}"]`)?.content
  }

  // Re-apply highlighting after a Turbo navigation (the frame itself
  // persists, so connect() doesn't fire again — turbo:load does).
  refreshActive() {
    this.clearActive()
    this.applyDefaultExpansion()
    this.markActiveTrail()
  }

  clearActive() {
    this.element.querySelectorAll(".module-nav__node--active, .module-nav__node--upstream")
      .forEach(n => n.classList.remove("module-nav__node--active", "module-nav__node--upstream"))
  }

  // Framework groups: open the active framework (leave others as the
  // user left them — don't collapse their manual expansions).
  applyDefaultExpansion() {
    const active = this.activeFramework
    this.groupTargets.forEach(group => {
      if (group.dataset.frameworkSlug === active) group.open = true
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

  // "Show ecosystem gems" checkbox (rails nav only). The ecosystem trees
  // aren't hidden in the default payload — they're only rendered when the
  // frame is requested with ?ecosystem=1 — so toggling reloads the frame
  // with or without the param. The preference persists in localStorage;
  // reconcileEcosystem() re-applies it on connect (fresh loads, and the
  // frame reload the toggle itself triggers — where stored == checked, so
  // it settles without looping).
  toggleEcosystem() {
    const on = this.ecosystemTarget.checked
    try { localStorage.setItem("module-nav-ecosystem", on ? "1" : "0") } catch {}
    this.reloadFrame(on)
  }

  reconcileEcosystem() {
    if (!this.hasEcosystemTarget) return
    let stored
    try { stored = localStorage.getItem("module-nav-ecosystem") === "1" } catch { return }
    if (stored !== this.ecosystemTarget.checked) {
      this.ecosystemTarget.checked = stored
      this.reloadFrame(stored)
    }
  }

  reloadFrame(withEcosystem) {
    const frame = this.element.closest("turbo-frame")
    if (!frame?.src) return
    const url = new URL(frame.src, window.location.origin)
    if (withEcosystem) url.searchParams.set("ecosystem", "1")
    else url.searchParams.delete("ecosystem")

    // Setting src while the frame is still completing a load gets
    // swallowed by Turbo (the attribute updates, the content doesn't) —
    // wait for the in-flight load to finish first.
    const apply = () => { frame.src = url.toString() }
    if (frame.complete) apply()
    else frame.addEventListener("turbo:frame-load", apply, { once: true })
  }

  markActiveTrail() {
    const active = this.activeFqn
    if (!active) return
    const upstream = new Set(this.upstreamFqns.map(s => s.toLowerCase()))

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

    // Announce the outcome — the tree filtering itself is silent.
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = !filtering ? ""
        : anyVisible ? `Filtered to matches for ${query}` : "No matches"
    }
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
