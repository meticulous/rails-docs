import { Controller } from "@hotwired/stimulus"

// Global "/" shortcut to focus the inline header search box, and "?" to
// open the keyboard-shortcuts help overlay (a server-rendered <dialog>,
// shared/_shortcuts_help.html.erb). ⌘/Ctrl-K is bound by the layout's
// data-action to search-palette#open (the modal command palette).
//
// The controller is attached to <body>; the search input and help
// dialog are found by selector so they don't need data-keyboard-target
// wiring — the help dialog's own backdrop click and Escape key are
// wired via data-action straight back to this controller (see the
// partial), same division of labor as search-palette's dialog.
export default class extends Controller {
  connect() {
    this.boundHandle = this.handle.bind(this)
    document.addEventListener("keydown", this.boundHandle)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandle)
  }

  handle(event) {
    if (this.isTypingInField(event.target)) return

    if (event.key === "/") {
      event.preventDefault()
      this.focusSearch()
    } else if (event.key === "?") {
      event.preventDefault()
      this.openHelp()
    }
  }

  focusSearch() {
    const input = document.querySelector(".site-header__search input[name=q]")
    if (!input) return
    input.focus()
    input.select()
  }

  openHelp() {
    const dialog = document.querySelector(".shortcuts-help")
    if (!dialog || dialog.open) return
    dialog.showModal()
  }

  // Bound from the dialog's own data-action (click on the backdrop, and
  // keydown for Escape). Closing Escape explicitly — rather than relying
  // solely on the dialog's native "cancel" event — matches the fix
  // already applied to the search palette: Safari/WebKit can swallow
  // Escape before it reaches native dialog handling when focus is inside
  // certain elements, so we handle it ourselves for consistency.
  closeHelp(event) {
    if (event.type === "keydown" && event.key !== "Escape") return
    if (event.type === "click" && event.target !== event.currentTarget) return
    event.preventDefault()
    const dialog = document.querySelector(".shortcuts-help")
    if (dialog?.open) dialog.close()
  }

  isTypingInField(target) {
    const tag = target.tagName
    return tag === "INPUT" || tag === "TEXTAREA" || target.isContentEditable
  }
}
