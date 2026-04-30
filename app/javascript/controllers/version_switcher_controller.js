import { Controller } from "@hotwired/stimulus"

// Warps to the same entity in another version when the dropdown changes.
// If the entity doesn't exist in the chosen version, the controller falls
// back to that version's home page (handled server-side by 404 -> redirect
// in a future iteration; for now the user sees a 404 which is honest).
export default class extends Controller {
  switch(event) {
    const segment = event.target.value
    const path = window.location.pathname.split("/").slice(2).join("/")
    window.location.href = `/${segment}/${path}`
  }
}
