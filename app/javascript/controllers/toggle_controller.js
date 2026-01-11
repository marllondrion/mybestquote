import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["control", "section"]

    connect() {
        this.update()
    }

    update() {
        const checked = this.controlTarget.checked
        this.sectionTarget.classList.toggle("hidden", !checked)
    }
}