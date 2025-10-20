import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "searchInput",
    "resultsDropdown",
    "selectedDisplay",
    "selectedTags",
    "emptyMessage",
    "selectedCount",
    "foodIdsField"
  ]

  static values = {
    minFoods: { type: Number, default: 2 },
    maxFoods: { type: Number, default: 5 },
    searchUrl: String,
    initialFoodIds: String,
    foodNameMap: String
  }

  connect() {
    console.log(`=== FOOD SELECTOR CONTROLLER CONNECTED ===`)
    console.log(`=== searchUrlValue: ${this.searchUrlValue}`)
    console.log(`=== initialFoodIdsValue: ${this.initialFoodIdsValue}`)
    console.log(`=== foodNameMapValue: ${this.foodNameMapValue}`)

    // Initialize food names map from the server (pre-hydrated for edit view)
    try {
      this.foodNames = this.foodNameMapValue ? JSON.parse(this.foodNameMapValue) : {}
      console.log(`=== Initialized foodNames map: `, this.foodNames)
    } catch (e) {
      console.error(`=== Error parsing foodNameMap: `, e)
      this.foodNames = {}
    }

    // Initialize with food_ids from the data attribute (for editing)
    try {
      const initialIds = this.initialFoodIdsValue ? JSON.parse(this.initialFoodIdsValue) : []
      this.selectedFoodIds = new Set(initialIds)
      console.log(`=== Initialized with food IDs: `, Array.from(this.selectedFoodIds))
    } catch (e) {
      console.error(`=== Error parsing initialFoodIds: `, e)
      this.selectedFoodIds = new Set()
    }

    this.updateSelectedDisplay()

    // Add event listeners for closing dropdown
    document.addEventListener("click", this.handleClickOutside.bind(this))
    document.addEventListener("keydown", this.handleKeyDown.bind(this))
  }

  disconnect() {
    document.removeEventListener("click", this.handleClickOutside.bind(this))
    document.removeEventListener("keydown", this.handleKeyDown.bind(this))
  }

  // Fetch foods when input gets focus (show first 20 alphabetically)
  onInputFocus(event) {
    console.log(`=== ON INPUT FOCUS called`)
    if (this.searchInputTarget.value.trim() === "") {
      console.log(`=== Fetching all foods`)
      this.fetchFoods("")
    }
  }

  // Fetch foods on input with debounce (min 1 character)
  async onInputChange(event) {
    const query = this.searchInputTarget.value.trim()

    if (query.length === 0) {
      this.resultsDropdownTarget.innerHTML = ""
      this.resultsDropdownTarget.classList.add("hidden")
      return
    }

    await this.fetchFoods(query)
  }

  async fetchFoods(query) {
    try {
      console.log(`=== FETCH FOODS CALLED with query: "${query}"`)
      console.log(`=== this.searchUrlValue: ${this.searchUrlValue}`)

      const url = new URL(this.searchUrlValue, window.location.origin)
      url.searchParams.set("q", query)

      console.log(`=== Final URL: ${url.toString()}`)

      const response = await fetch(url.toString(), {
        headers: { "Accept": "application/json" }
      })

      if (!response.ok) throw new Error("Food search failed")

      const foods = await response.json()
      this.renderResults(foods)
    } catch (error) {
      console.error("Food search error:", error)
      this.resultsDropdownTarget.innerHTML = '<div class="p-2 text-sm text-red-600">Error loading foods</div>'
      this.resultsDropdownTarget.classList.remove("hidden")
    }
  }

  renderResults(foods) {
    console.log(`=== RENDER RESULTS called with ${foods.length} foods`)
    this.lastResults = foods // Store for re-rendering

    // Store food names for display in tags
    foods.forEach(food => {
      this.foodNames[food.id] = food.description
    })

    if (foods.length === 0) {
      this.resultsDropdownTarget.innerHTML = '<div class="p-2 text-sm text-gray-500">No foods found</div>'
    } else {
      const html = foods.map(food => {
        const isSelected = this.selectedFoodIds.has(food.id)
        const canSelect = !isSelected && this.selectedFoodIds.size >= this.maxFoodsValue

        return `
          <button type="button"
                  class="w-full text-left px-3 py-2 text-sm hover:bg-gray-100 ${isSelected ? "bg-indigo-100 font-medium" : ""} ${canSelect ? "opacity-50 cursor-not-allowed" : "cursor-pointer"}"
                  data-action="click->food-selector#toggleFood"
                  data-food-id="${food.id}"
                  data-food-name="${this.escapeHtml(food.description)}"
                  ${canSelect ? "disabled" : ""}>
            ${this.escapeHtml(food.description)}
          </button>
        `
      }).join("")

      this.resultsDropdownTarget.innerHTML = html
    }

    this.resultsDropdownTarget.classList.remove("hidden")
  }

  toggleFood(event) {
    event.preventDefault()

    console.log(`=== TOGGLE FOOD CALLED`)
    console.log(`=== event.currentTarget: `, event.currentTarget)
    console.log(`=== event.currentTarget.dataset: `, event.currentTarget.dataset)

    const foodId = parseInt(event.currentTarget.dataset.foodId)
    const foodName = event.currentTarget.dataset.foodName

    console.log(`=== foodId: ${foodId}, foodName: ${foodName}`)

    if (this.selectedFoodIds.has(foodId)) {
      console.log(`=== Removing foodId ${foodId}`)
      this.selectedFoodIds.delete(foodId)
    } else {
      if (this.selectedFoodIds.size >= this.maxFoodsValue) {
        console.log(`=== Max foods reached, showing limit message`)
        this.showLimitMessage()
        return
      }
      console.log(`=== Adding foodId ${foodId}`)
      this.selectedFoodIds.add(foodId)
    }

    console.log(`=== Updated selectedFoodIds: `, Array.from(this.selectedFoodIds))

    this.updateSelectedDisplay()
    this.renderResults(this.lastResults || []) // Re-render to update checkboxes
    this.searchInputTarget.focus()
  }

  showLimitMessage() {
    const message = `Maximum ${this.maxFoodsValue} foods allowed`
    alert(message) // TODO: Replace with inline toast/notification
  }

  updateSelectedDisplay() {
    this.selectedCountTarget.textContent = this.selectedFoodIds.size

    // Remove all existing dynamic hidden fields
    this.removeExistingFoodIdFields()

    // Create new hidden input fields for each food ID
    // Rails expects multiple inputs with the same name ending in [] to create an array
    this.createFoodIdFields()

    if (this.selectedFoodIds.size === 0) {
      this.selectedTagsTarget.innerHTML = '<span class="text-xs text-gray-500 italic">None selected yet</span>'
    } else {
      const tagsHTML = Array.from(this.selectedFoodIds)
        .map(id => {
          const foodName = this.foodNames[id] || `Food #${id}`
          return `<span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-indigo-100 text-indigo-800">${this.escapeHtml(foodName)}</span>`
        })
        .join("")

      this.selectedTagsTarget.innerHTML = tagsHTML
    }
  }

  removeExistingFoodIdFields() {
    // Remove all hidden inputs with data-dynamic-food-field attribute
    const existing = this.element.querySelectorAll('input[data-dynamic-food-field]')
    existing.forEach(field => field.remove())
    console.log(`=== Removed existing food_id fields`)
  }

  createFoodIdFields() {
    // Get the base field name from the reference field
    // e.g., "daily_meal_structure[meal_structure_items_attributes][0][food_ids]"
    // We need to create: "daily_meal_structure[meal_structure_items_attributes][0][food_ids][]"
    const baseFieldName = this.foodIdsFieldTarget.name
    const fieldNameWithBrackets = `${baseFieldName}[]`

    console.log(`=== Creating food_id fields with name: ${fieldNameWithBrackets}`)

    Array.from(this.selectedFoodIds).forEach(foodId => {
      const input = document.createElement('input')
      input.type = 'hidden'
      input.name = fieldNameWithBrackets
      input.value = foodId
      input.setAttribute('data-dynamic-food-field', 'true')
      this.element.appendChild(input)
      console.log(`=== Created hidden field: ${fieldNameWithBrackets} = ${foodId}`)
    })

    console.log(`=== Total food_id fields created: ${this.selectedFoodIds.size}`)
  }

  // Hide dropdown when clicking outside the controller element
  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.resultsDropdownTarget.classList.add("hidden")
    }
  }

  // Handle Escape key to close dropdown
  handleKeyDown(event) {
    if (event.key === "Escape") {
      this.resultsDropdownTarget.classList.add("hidden")
      this.searchInputTarget.blur()
    }
  }

  // Helper to escape HTML to prevent XSS
  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
