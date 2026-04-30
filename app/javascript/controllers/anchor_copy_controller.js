import { Controller } from "@hotwired/stimulus"

// Adds a GitHub-style "#" affordance next to every h1–h4 with an id.
// Hover reveals it; clicking copies the heading's permalink to the
// clipboard and updates the URL fragment without a scroll jump.
export default class extends Controller {
  connect() {
    this.element.querySelectorAll("h1[id], h2[id], h3[id], h4[id]").forEach(heading => {
      if (heading.querySelector(".anchor-link")) return
      const link = document.createElement("a")
      link.href = `#${heading.id}`
      link.className = "anchor-link"
      link.setAttribute("aria-label", "Copy link to this section")
      link.textContent = "#"
      link.addEventListener("click", this.copy.bind(this))
      heading.appendChild(link)
    })
  }

  copy(event) {
    event.preventDefault()
    const id = event.currentTarget.getAttribute("href").replace(/^#/, "")
    const url = `${window.location.origin}${window.location.pathname}#${id}`
    navigator.clipboard?.writeText(url)
    history.replaceState(null, "", `#${id}`)
    event.currentTarget.classList.add("anchor-link--copied")
    setTimeout(() => event.currentTarget.classList.remove("anchor-link--copied"), 1200)
  }
}
