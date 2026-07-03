// Shared screen-reader announcer. The layout renders a single
// visually-hidden role="status" node (#live-status); widgets funnel
// transient confirmations ("Code copied") through it, and Turbo page
// visits announce the new page title — Turbo swaps <body> without
// telling assistive tech anything changed.
export function announce(message) {
  const status = document.getElementById("live-status")
  if (!status) return
  // Clear first so repeating the same message re-announces.
  status.textContent = ""
  requestAnimationFrame(() => { status.textContent = message })
}

let lastAnnouncedPath = window.location.pathname

document.addEventListener("turbo:load", () => {
  if (window.location.pathname === lastAnnouncedPath) return
  lastAnnouncedPath = window.location.pathname
  announce(document.title)
})
