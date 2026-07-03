import { Controller } from "@hotwired/stimulus"

// Light/dark/system theme toggle. Cycles light → dark → system on click.
// Persists choice to localStorage; initial render reads localStorage to
// avoid a flash of unstyled theme on subsequent loads.
export default class extends Controller {
  static targets = ["button"]

  connect() {
    const stored = localStorage.getItem("theme")
    this.applyTheme(stored || "system")
  }

  toggle() {
    const current = localStorage.getItem("theme") || "system"
    const next = { light: "dark", dark: "system", system: "light" }[current]
    localStorage.setItem("theme", next)
    this.applyTheme(next)
  }

  applyTheme(theme) {
    if (theme === "system") {
      this.element.removeAttribute("data-theme")
    } else {
      this.element.setAttribute("data-theme", theme)
    }
    if (this.hasButtonTarget) {
      // No aria-pressed: a binary pressed state can't represent a
      // three-way cycle — the label names the current state and what
      // activating does instead.
      this.buttonTarget.textContent = ({ light: "☀", dark: "☾", system: "◑" })[theme]
      this.buttonTarget.setAttribute("aria-label", {
        light: "Theme: light. Activate to switch to dark.",
        dark: "Theme: dark. Activate to switch to system.",
        system: "Theme: system. Activate to switch to light."
      }[theme])
    }
  }
}
