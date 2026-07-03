import { Controller } from "@hotwired/stimulus"

// Attached to the lazy module-nav turbo-frame stub in the layout.
// Applies the persisted "Show ecosystem gems" preference to the frame's
// src *before* the lazy load fires, so a returning user's first nav
// fetch already carries ?ecosystem=1 — no plain-then-reload double
// fetch, and no race against the frame's initial load (setting src on
// a frame that is mid-load gets swallowed by Turbo).
export default class extends Controller {
  connect() {
    let on
    try { on = localStorage.getItem("module-nav-ecosystem") === "1" } catch { return }
    if (!on || !this.element.src || this.element.complete) return

    const url = new URL(this.element.src, window.location.origin)
    url.searchParams.set("ecosystem", "1")
    this.element.src = url.toString()
  }
}
