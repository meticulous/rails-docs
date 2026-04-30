import { Controller } from "@hotwired/stimulus"

// Global keyboard shortcuts.
//
//   ⌘/Ctrl-K  → focus the site-header search box
//   /         → focus the search box (when not already in an input)
//
// The controller is attached to <body>; targets are found by selector so
// individual elements don't need data-keyboard-target wiring.
export default class extends Controller {
  connect() {
    this.boundHandle = this.handle.bind(this)
    document.addEventListener("keydown", this.boundHandle)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandle)
  }

  handle(event) {
    if ((event.metaKey || event.ctrlKey) && event.key === "k") {
      event.preventDefault()
      this.focusSearch()
      return
    }

    if (event.key === "/" && !this.isTypingInField(event.target)) {
      event.preventDefault()
      this.focusSearch()
    }
  }

  focusSearch() {
    const input = document.querySelector(".site-header__search input[name=q]")
    if (!input) return
    input.focus()
    input.select()
  }

  isTypingInField(target) {
    const tag = target.tagName
    return tag === "INPUT" || tag === "TEXTAREA" || target.isContentEditable
  }
}
