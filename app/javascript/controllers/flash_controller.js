import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { timeout: Number }

  connect() {
    const timeoutMs = this.timeoutValue || 2000

    this._timeout = setTimeout(() => {
      this.dismiss()
    }, timeoutMs)
  }

  disconnect() {
    if (this._timeout) clearTimeout(this._timeout)
  }

  dismiss() {
    // animate out
    this.element.classList.add("opacity-0", "-translate-y-2")

    // remove after transition
    setTimeout(() => {
      this.element.remove()
    }, 300)
  }
}
