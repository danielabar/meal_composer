# TODO: Technically this is a MacroLookupService because it only looks up carbs/protein/fat.
# TODO: Would be nice to also return net carbs (carbs minus fiber and sugar alcohols)
class NutrientLookupService
  # Nutrient names verified against db/data/fndds/nutrient.csv
  CARB_NUTRIENT_NAMES = [
    "Carbohydrate, by difference",
    "Carbohydrate, by summation",
    "Carbohydrates",           # Added from FNDDS
    "Carbohydrate, other",     # Added from FNDDS
    "Total carbohydrate"       # Not in FNDDS but kept for Foundation Foods compatibility
  ].freeze

  PROTEIN_NUTRIENT_NAMES = [
    "Protein",
    "Adjusted Protein"
  ].freeze

  FAT_NUTRIENT_NAMES = [
    "Total lipid (fat)",
    "Total fat (NLEA)",
    "Lipids",               # Added from FNDDS
    "Fat, total"            # Not in FNDDS but kept for Foundation Foods compatibility
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
