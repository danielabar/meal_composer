class NutrientLookupService
  CARB_NUTRIENT_NAMES = [
    "Carbohydrate, by difference",
    "Carbohydrate, by summation",
    "Total carbohydrate"
  ].freeze

  PROTEIN_NUTRIENT_NAMES = [
    "Protein",
    "Adjusted Protein"
  ].freeze

  FAT_NUTRIENT_NAMES = [
    "Total lipid (fat)",
    "Total fat (NLEA)",
    "Fat, total"
  ].freeze

  def self.macronutrients_for(food)
    new(food).macronutrients
  end

  def initialize(food)
    @food = food
  end

  def macronutrients
    {
      carbohydrates: find_nutrient_amount(CARB_NUTRIENT_NAMES),
      protein: find_nutrient_amount(PROTEIN_NUTRIENT_NAMES),
      fat: find_nutrient_amount(FAT_NUTRIENT_NAMES)
    }
  end

  private

  attr_reader :food

  def find_nutrient_amount(nutrient_names)
    nutrient_names.each do |name|
      nutrient = Nutrient.find_by(name: name, unit_name: "G")
      next unless nutrient

      amount = food.food_nutrients.find_by(nutrient_id: nutrient.id)&.amount
      return amount if amount
    end
    nil
  end
end
