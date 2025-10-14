class FoodPortion < ApplicationRecord
  belongs_to :meal
  belongs_to :food

  validates :grams, presence: true, numericality: { greater_than: 0 }

  # TODO: Unused for now, not too crazy about AR model calling service, think about this later.
  # Calculate macros for this food portion
  def macros
    food_macros = NutrientLookupService.macronutrients_for(food)
    multiplier = grams / 100.0

    {
      carbs: (food_macros[:carbohydrates] || 0) * multiplier,
      protein: (food_macros[:protein] || 0) * multiplier,
      fat: (food_macros[:fat] || 0) * multiplier
    }
  end

  # Human-readable representation
  def to_s
    "#{grams}g of #{food.description}"
  end
end
