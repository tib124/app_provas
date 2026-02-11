import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "tipo",
    "respostasWrapper",
    "respostas",
    "respostaSelectWrapper",
    "respostaSelect",
    "respostaTextWrapper",
    "respostaText"
  ]

  connect() {
    this.toggle()
  }

  toggle() {
    const tipo = this.tipoTarget.value
    const isMultipla = tipo === "multipla_escolha"

    this.respostasWrapperTarget.classList.toggle("hidden", !isMultipla)
    this.respostasTarget.disabled = !isMultipla

    this.respostaSelectWrapperTarget.classList.toggle("hidden", !isMultipla)
    this.respostaSelectTarget.disabled = !isMultipla

    this.respostaTextWrapperTarget.classList.toggle("hidden", isMultipla)
    this.respostaTextTarget.disabled = isMultipla

    if (isMultipla) this.syncSelectOptions()
  }

  syncSelectOptions() {
    const labels = this.extractLabels(this.respostasTarget.value)

    const current = (this.respostaSelectTarget.value || "").toUpperCase().trim()
    const hasCurrent = current && labels.includes(current)

    this.respostaSelectTarget.innerHTML = ""

    const placeholder = document.createElement("option")
    placeholder.value = ""
    placeholder.textContent = "Selecione…"
    this.respostaSelectTarget.appendChild(placeholder)

    labels.forEach((label) => {
      const opt = document.createElement("option")
      opt.value = label
      opt.textContent = label
      this.respostaSelectTarget.appendChild(opt)
    })

    if (hasCurrent) this.respostaSelectTarget.value = current
  }

  extractLabels(text) {
    return Array.from(
      new Set(
        (text || "")
          .split(/\r?\n/)
          .map((line) => line.trim())
          .map((line) => {
            const m = line.match(/^([A-Za-z])\s*(?:\-|\)|\.|\])\s*/)
            return m ? m[1].toUpperCase() : null
          })
          .filter(Boolean)
      )
    )
  }
}
