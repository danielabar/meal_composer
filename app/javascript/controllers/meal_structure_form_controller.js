import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["mealsContainer", "mealTemplate", "mealItem"]

  addMeal(event) {
    event.preventDefault()

    // Get the template content
    const template = this.mealTemplateTarget.content.cloneNode(true)

    // Replace NEW_RECORD with a timestamp to make it unique
    const timestamp = new Date().getTime()
    const html = template.firstElementChild.outerHTML.replace(/NEW_RECORD/g, timestamp)

    // Insert the new meal item
    this.mealsContainerTarget.insertAdjacentHTML('beforeend', html)
  }

  removeMeal(event) {
    event.preventDefault()

    const mealItem = event.target.closest('[data-meal-structure-form-target="mealItem"]')

    // Find the _destroy hidden field and set it to true
    const destroyField = mealItem.querySelector('input[name*="_destroy"]')

    if (destroyField) {
      destroyField.value = '1'
    }

    // Hide the meal item
    mealItem.style.display = 'none'
  }
}
