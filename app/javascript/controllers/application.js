// https://stimulus.hotwired.dev/handbook/installing

import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus   = application

import AutosubmitController from "./autosubmit_controller"
application.register("autosubmit", AutosubmitController)

import ToggleController from "./toggle_controller"
application.register("toggle", ToggleController)

export { application }
