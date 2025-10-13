import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["carbs", "protein", "fat", "calories"];

  connect() {
    this.calculate();
  }

  calculate() {
    const carbs = parseFloat(this.carbsTarget.value) || 0;
    const protein = parseFloat(this.proteinTarget.value) || 0;
    const fat = parseFloat(this.fatTarget.value) || 0;

    // 4 cal/g for carbs & protein, 9 cal/g for fat
    const calories = Math.round(carbs * 4 + protein * 4 + fat * 9);

    this.caloriesTarget.textContent = calories;
  }
}
