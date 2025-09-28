require 'rails_helper'

RSpec.describe Food, type: :model do
  describe "#macronutrients" do
    it "returns the macronutrients" do
      food = create(:food)
      carb_nutrient = create(:nutrient, name: "Carbohydrate, by difference", unit_name: "G")
      protein_nutrient = create(:nutrient, name: "Protein", unit_name: "G")
      fat_nutrient = create(:nutrient, name: "Total lipid (fat)", unit_name: "G")

      create(:food_nutrient, fdc_id: food.fdc_id, nutrient: carb_nutrient, amount: 1.0)
      create(:food_nutrient, fdc_id: food.fdc_id, nutrient: protein_nutrient, amount: 2.0)
      create(:food_nutrient, fdc_id: food.fdc_id, nutrient: fat_nutrient, amount: 3.0)

      macronutrients = food.macronutrients

      expect(macronutrients[:carbohydrates]).to eq(1.0)
      expect(macronutrients[:protein]).to eq(2.0)
      expect(macronutrients[:fat]).to eq(3.0)
    end
  end
end
