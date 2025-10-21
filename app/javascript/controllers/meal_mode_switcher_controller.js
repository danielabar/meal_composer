import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["categoriesSection", "foodsSection"]

  connect() {
    // Initialize visibility based on current mode
    this.updateVisibility()
  }

  toggleSection(event) {
    this.updateVisibility()
  }

  updateVisibility() {
    // Find the radio button value within this controller's scope
    const modeRadios = this.element.querySelectorAll('input[type="radio"][name*="mode"]')
    let selectedMode = "category" // default

    modeRadios.forEach(radio => {
      if (radio.checked) {
        selectedMode = radio.value
      }
    })

    // Show/hide sections based on selected mode
    if (selectedMode === "category") {
      this.categoriesSectionTarget.classList.remove("hidden")
      this.foodsSectionTarget.classList.add("hidden")
    } else if (selectedMode === "food") {
      this.categoriesSectionTarget.classList.add("hidden")
      this.foodsSectionTarget.classList.remove("hidden")
    }
  }
}
