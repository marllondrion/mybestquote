import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.innerHTML = "<span class='text-green-600 font-bold'>🚀 Hotwire is Active!</span>"
  }
}