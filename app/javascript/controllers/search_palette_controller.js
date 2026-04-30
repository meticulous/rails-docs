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
    fqn.textContent = result.fqn
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

  highlight(event) {
    const idx = parseInt(event.currentTarget.dataset.index, 10)
    if (Number.isNaN(idx)) return
    this.setActive(idx)
  }

  onKeydown(event) {
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
