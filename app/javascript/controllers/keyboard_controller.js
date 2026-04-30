import { Controller } from "@hotwired/stimulus"

// Global "/" shortcut to focus the inline header search box. ⌘/Ctrl-K
// is owned by search_palette_controller (it opens the modal palette).
//
// The controller is attached to <body>; the search input is found by
// selector so it doesn't need data-keyboard-target wiring.
export default class extends Controller {
  connect() {
    this.boundHandle = this.handle.bind(this)
    document.addEventListener("keydown", this.boundHandle)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandle)
  }

  handle(event) {
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
