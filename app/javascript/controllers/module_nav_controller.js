import { Controller } from "@hotwired/stimulus"

// Filter the persistent left module-nav as the user types. Each <li>
// carries data-fqn (lowercased FQN) so we do a substring match without
// re-querying the DOM. While filtering, every framework <details>
// auto-expands so matches in collapsed groups are still visible; when
// the filter clears, groups restore to their default state (only the
// active-framework group open).
export default class extends Controller {
  static targets = ["filter", "list", "empty", "group"]
  static values = { activeFramework: String }

  connect() {
    this.applyDefaultExpansion()
  }

  applyDefaultExpansion() {
    this.groupTargets.forEach(group => {
      group.open = group.dataset.frameworkSlug === this.activeFrameworkValue
    })
  }

  filter() {
    const query = this.filterTarget.value.trim().toLowerCase()
    const filtering = query.length > 0
    let visibleTotal = 0

    this.groupTargets.forEach(group => {
      let visibleInGroup = 0
      group.querySelectorAll(".module-nav__item").forEach(item => {
        const matches = !filtering || item.dataset.fqn.includes(query)
        item.hidden = !matches
        if (matches) visibleInGroup++
      })
      group.hidden = filtering && visibleInGroup === 0
      if (filtering) {
        group.open = visibleInGroup > 0
      }
      visibleTotal += visibleInGroup
    })

    if (!filtering) this.applyDefaultExpansion()
    this.emptyTarget.hidden = visibleTotal > 0
  }
}
