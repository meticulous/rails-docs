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
      this.element.setAttribute("aria-expanded", "false")
    }
  }

  toggle() {
    const collapsed = document.body.classList.toggle("module-nav--collapsed")
    localStorage.setItem(STORAGE_KEY, collapsed ? "1" : "0")
    this.element.setAttribute("aria-expanded", collapsed ? "false" : "true")
  }
}
