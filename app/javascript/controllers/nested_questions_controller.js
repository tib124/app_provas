import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template"]

  add() {
    const content = this.templateTarget.innerHTML.replaceAll(
      "NEW_RECORD",
      String(Date.now())
    )

    this.containerTarget.insertAdjacentHTML("beforeend", content)
  }

  remove(event) {
    const questionEl = event.target.closest("[data-nested-questions-question]")
    if (!questionEl) return

    const destroyInput = questionEl.querySelector(
      'input[name*="[_destroy]"]'
    )

    if (destroyInput) {
      destroyInput.value = "1"
      questionEl.classList.add("hidden")
    } else {
      questionEl.remove()
    }
  }
}
