import { Controller } from "@hotwired/stimulus"

// Triggered by the "Compare with…" select on entity pages. Navigates to
// the diff URL for whichever version the user picked. Empty option is a
// no-op so the field reads cleanly when nothing is selected.
export default class extends Controller {
  go(event) {
    const url = event.target.value
    if (url) window.location.href = url
  }
}
