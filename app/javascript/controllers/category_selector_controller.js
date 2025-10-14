import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["selectedDisplay", "selectedTags", "selectedCount", "emptyMessage"]

  connect() {
    // Initialize the selected categories display on page load
    this.updateSelected()
  }

  updateSelected() {
    // Find all checked checkboxes within this controller's scope
    const checkboxes = this.element.querySelectorAll('input[type="checkbox"]:checked')
    const selectedCategories = []

    checkboxes.forEach(checkbox => {
      const categoryName = checkbox.dataset.categoryName
      if (categoryName) {
        selectedCategories.push(categoryName)
      }
    })

    // Update the count
    this.selectedCountTarget.textContent = selectedCategories.length

    // Update the tags display
    if (selectedCategories.length === 0) {
      this.selectedTagsTarget.innerHTML = '<span class="text-xs text-gray-500 italic">None selected yet</span>'
    } else {
      // Sort alphabetically for easier reading
      selectedCategories.sort()

      const tagsHTML = selectedCategories.map(name => {
        return `<span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-indigo-100 text-indigo-800">${this.escapeHtml(name)}</span>`
      }).join('')

      this.selectedTagsTarget.innerHTML = tagsHTML
    }
  }

  // Helper to escape HTML to prevent XSS
  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
