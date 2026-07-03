import { Controller } from "@hotwired/stimulus"

// Decorates every Rouge-highlighted code block (pre.highlight — method
// signatures, source listings, doc examples; see
// SyntaxHighlightHelper#highlight_code/#highlight_doc_code) with a small
// copy-to-clipboard button, top-right of the block.
//
// Attached at a container level (the layout's <main>) rather than per
// pre.highlight, since those blocks are rendered from many different
// partials across entity/doc views. connect() decorates whatever is
// already in the DOM; turbo:load re-decorates after each Turbo
// navigation the same way module_nav_controller.js re-applies its
// active-trail highlighting (the controller's element itself may be
// restored from Turbo's cache or replaced by a fresh render, so we
// can't rely on connect() firing again — turbo:load fires either way).
//
// Decoration is idempotent: a pre.highlight that already has a button
// (e.g. restored from Turbo's bfcache-like page cache) is skipped.
export default class extends Controller {
  connect() {
    this.boundDecorate = this.decorate.bind(this)
    document.addEventListener("turbo:load", this.boundDecorate)
    this.decorate()
  }

  disconnect() {
    document.removeEventListener("turbo:load", this.boundDecorate)
  }

  decorate() {
    this.element.querySelectorAll("pre.highlight").forEach(pre => {
      if (pre.querySelector(".code-copy")) return

      const button = document.createElement("button")
      button.type = "button"
      button.className = "code-copy"
      button.setAttribute("aria-label", "Copy code to clipboard")
      button.textContent = "Copy"
      button.addEventListener("click", this.copy.bind(this))
      pre.appendChild(button)
    })
  }

  copy(event) {
    const button = event.currentTarget
    const pre = button.closest("pre.highlight")
    const code = pre.querySelector("code")?.textContent ?? ""

    if (!navigator.clipboard) return

    navigator.clipboard.writeText(code).then(() => {
      button.textContent = "Copied"
      button.classList.add("code-copy--copied")
      clearTimeout(button._resetTimer)
      button._resetTimer = setTimeout(() => {
        button.textContent = "Copy"
        button.classList.remove("code-copy--copied")
      }, 1500)
    }).catch(() => {})
  }
}
