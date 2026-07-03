import { Controller } from "@hotwired/stimulus"

// Modal command palette opened with ⌘K / Ctrl-K. Debounced fetch to
// /search/suggest, arrow-key navigation, Enter to open the highlighted
// result, Escape to dismiss.
export default class extends Controller {
  static targets = ["dialog", "input", "results", "empty"]

  connect() {
    this.activeIndex = -1
    this.lastQuery = ""
  }

  open(event) {
    event?.preventDefault?.()
    if (this.dialogTarget.open) return
    this.dialogTarget.showModal()
    this.inputTarget.value = ""
    this.resultsTarget.replaceChildren()
    this.emptyTarget.hidden = false
    this.activeIndex = -1
    requestAnimationFrame(() => this.inputTarget.focus())
  }

  close() {
    if (this.dialogTarget.open) this.dialogTarget.close()
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  onInput(event) {
    const q = event.target.value.trim()
    clearTimeout(this.debounceTimer)
    if (q.length < 2) {
      this.resultsTarget.replaceChildren()
      this.emptyTarget.hidden = false
      this.activeIndex = -1
      return
    }
    this.debounceTimer = setTimeout(() => this.fetchSuggestions(q), 120)
  }

  async fetchSuggestions(q) {
    if (q === this.lastQuery) return
    this.lastQuery = q
    try {
      const res = await fetch(`/search/suggest.json?q=${encodeURIComponent(q)}`)
      const data = await res.json()
      this.render(data.results || [])
    } catch (err) {
      console.error("search palette fetch failed", err)
    }
  }

  render(results) {
    this.activeIndex = -1
    this.emptyTarget.hidden = results.length > 0
    this.resultsTarget.replaceChildren(...results.map((r, i) => this.buildResult(r, i)))
  }

  buildResult(result, index) {
    const li = document.createElement("li")
    li.className = "palette__item"
    li.dataset.action = "click->search-palette#go mouseenter->search-palette#highlight"
    li.dataset.url = result.url
    li.dataset.index = index

    const fqn = document.createElement("code")
    fqn.className = "palette__fqn"
    fqn.appendChild(this.buildFqn(result.fqn))
    li.appendChild(fqn)

    const kind = document.createElement("span")
    kind.className = "palette__kind"
    kind.textContent = result.kind
    li.appendChild(kind)

    if (result.summary) {
      const summary = document.createElement("p")
      summary.className = "palette__summary"
      summary.textContent = result.summary
      li.appendChild(summary)
    }

    return li
  }

  // Splits a fully-qualified name like
  // "ActiveModel::SecurePassword::ClassMethods#has_secure_password" into
  // the containing path ("ActiveModel::SecurePassword::ClassMethods::" or
  // "::") and the final segment ("has_secure_password"), so the path can
  // be de-emphasized and the name the user is scanning for stays at full
  // weight. Splits on whichever of the last "::" or "#" occurs later; a
  // bare name (no separator) renders with no path segment at all.
  buildFqn(fqn) {
    const fragment = document.createDocumentFragment()
    const splitAt = Math.max(fqn.lastIndexOf("::"), fqn.lastIndexOf("#"))

    if (splitAt === -1) {
      fragment.appendChild(document.createTextNode(fqn))
      return fragment
    }

    const separatorLength = fqn[splitAt] === "#" ? 1 : 2
    const path = fqn.slice(0, splitAt + separatorLength)
    const name = fqn.slice(splitAt + separatorLength)

    const pathSpan = document.createElement("span")
    pathSpan.className = "palette__fqn-path"
    pathSpan.textContent = path
    fragment.appendChild(pathSpan)

    const nameSpan = document.createElement("span")
    nameSpan.className = "palette__fqn-name"
    nameSpan.textContent = name
    fragment.appendChild(nameSpan)

    return fragment
  }

  highlight(event) {
    const idx = parseInt(event.currentTarget.dataset.index, 10)
    if (Number.isNaN(idx)) return
    this.setActive(idx)
  }

  onKeydown(event) {
    // Handle Escape explicitly rather than relying on the dialog's native
    // cancel behavior. Safari/WebKit intercepts Escape on a focused
    // `type="search"` input to clear its value first and does not forward
    // that keystroke to trigger the dialog's native Esc-to-close — so
    // `close()` never fires there, even though Chrome handles it for free.
    // Binding keydown here (on both the input and the dialog) and closing
    // explicitly makes Esc work the same way in every browser.
    if (event.key === "Escape") {
      event.preventDefault()
      this.close()
      return
    }

    const items = this.resultsTarget.querySelectorAll(".palette__item")
    if (event.key === "ArrowDown") {
      event.preventDefault()
      this.setActive(Math.min(this.activeIndex + 1, items.length - 1))
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.setActive(Math.max(this.activeIndex - 1, 0))
    } else if (event.key === "Enter") {
      event.preventDefault()
      const target = items[this.activeIndex] || items[0]
      if (target) window.location.href = target.dataset.url
    }
  }

  setActive(idx) {
    const items = this.resultsTarget.querySelectorAll(".palette__item")
    items.forEach((el, i) => el.classList.toggle("palette__item--active", i === idx))
    this.activeIndex = idx
    items[idx]?.scrollIntoView({ block: "nearest" })
  }

  go(event) {
    const url = event.currentTarget.dataset.url
    if (url) window.location.href = url
  }
}
