import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["container", "template"];

  connect() {
    console.log("Category form controller connected");
  }

  add(event) {
    console.log("=== ADD CATEGORY ===");
    event.preventDefault();

    // Generate a unique ID for the template replacement
    const uniqueId = new Date().getTime();

    // Create a copy of the template content
    let content = this.templateTarget.innerHTML.replace(
      /TEMPLATE_RECORD/g,
      uniqueId
    );

    // Calculate next position (number of existing items + 1)
    const nextPosition = this.containerTarget.querySelectorAll("[data-category-form-target='item']").length;

    // Replace the position value with the next sequential number
    content = content.replace(
      new RegExp(`value="${uniqueId}"`, "g"),
      `value="${nextPosition}"`
    );

    this.containerTarget.insertAdjacentHTML("beforeend", content);

    // Scroll to the newly added item
    this.containerTarget.lastElementChild.scrollIntoView({
      behavior: "smooth",
      block: "nearest",
    });
  }

  remove(event) {
    event.preventDefault();

    const wrapper = event.target.closest("[data-category-form-target='item']");

    // If item is persisted (has an ID), mark for destruction
    const destroyInput = wrapper.querySelector("input[name*='_destroy']");
    if (destroyInput) {
      destroyInput.value = "1";
      wrapper.style.display = "none";
    } else {
      // If new item, just remove it
      wrapper.remove();
    }
  }
}
