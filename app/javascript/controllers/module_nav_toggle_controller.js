import { Controller } from "@hotwired/stimulus"

// Toggles the persistent left module-nav. Adds/removes a class on
// <body> (not on the nav itself) so the layout grid can rebalance —
// CSS handles the actual hide and main-content reflow. Persists the
// open/closed state in localStorage so it sticks across navigations.
const STORAGE_KEY = "module-nav-collapsed"

export default class extends Controller {
  connect() {
    if (localStorage.getItem(STORAGE_KEY) === "1") {
      document.body.classList.add("module-nav--collapsed")
    }
    this.syncExpanded()
    // The nav rides in a lazy turbo-frame — re-sync once its content
    // actually arrives (connect() usually runs before that).
    this.boundSync = this.syncExpanded.bind(this)
    document.addEventListener("turbo:frame-load", this.boundSync)
  }

  disconnect() {
    document.removeEventListener("turbo:frame-load", this.boundSync)
  }

  toggle() {
    const collapsed = document.body.classList.toggle("module-nav--collapsed")
    localStorage.setItem(STORAGE_KEY, collapsed ? "1" : "0")
    this.syncExpanded()
  }

  // aria-expanded reflects whether the nav is actually visible, not the
  // collapsed class — CSS inverts the class's meaning on mobile (nav
  // hidden by default, the class *shows* it), so deriving state from
  // the class would misreport on one side of the breakpoint. Until the
  // lazy frame delivers the nav element, infer from breakpoint + class.
  syncExpanded() {
    const nav = document.querySelector(".module-nav")
    const collapsed = document.body.classList.contains("module-nav--collapsed")
    const mobile = window.matchMedia("(max-width: 60rem)").matches
    const shown = nav ? getComputedStyle(nav).display !== "none" : (mobile ? collapsed : !collapsed)
    this.element.setAttribute("aria-expanded", shown ? "true" : "false")
  }
}
