import { Controller } from "@hotwired/stimulus"

// Catches sdoc-style method anchors that survive a 301 from /classes/X.html
// to /v.../x. If the destination URL still has #method-i-foo or #method-c-foo
// in the fragment, redirect to the per-method page.
//
// MethodSlug encoding lives on the server; rather than re-implement it in
// JS, we hand the raw method name to the server and let it slug + redirect.
export default class extends Controller {
  connect() {
    const hash = window.location.hash
    const match = hash.match(/^#method-(i|c)-(.+)$/)
    if (!match) return

    const scope = match[1] === "c" ? "singleton" : "instance"
    const name = decodeURIComponent(match[2])
    const params = new URLSearchParams({ parent_path: window.location.pathname, name, scope })
    window.location.replace(`/_legacy_method?${params}`)
  }
}
