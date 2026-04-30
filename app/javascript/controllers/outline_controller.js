import { Controller } from "@hotwired/stimulus"

// Highlights the outline link matching whatever section the reader is
// currently looking at. The IntersectionObserver fires when an h2 with
// id="section-…" crosses into the viewport's middle band; the controller
// then sets aria-current="location" on the corresponding outline anchor.
export default class extends Controller {
  connect() {
    this.observer = new IntersectionObserver(this.onIntersect.bind(this), {
      rootMargin: "-20% 0% -60% 0%",
      threshold: 0
    })
    document.querySelectorAll("h2[id^='section-']").forEach(h => this.observer.observe(h))
  }

  disconnect() {
    this.observer?.disconnect()
  }

  onIntersect(entries) {
    entries.forEach(entry => {
      if (!entry.isIntersecting) return
      this.element.querySelectorAll("a[aria-current]").forEach(a => a.removeAttribute("aria-current"))
      const link = this.element.querySelector(`a[href="#${entry.target.id}"]`)
      link?.setAttribute("aria-current", "location")
    })
  }
}
