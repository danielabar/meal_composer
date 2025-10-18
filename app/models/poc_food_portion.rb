class PocFoodPortion
  attr_reader :food, :grams

  def initialize(food:, grams:)
    @food = food
    @grams = grams.to_f
  end

  def grams=(new_grams)
    @grams = new_grams.to_f
  end

  def macros
    food_macros = food.macronutrients
    multiplier = grams / 100.0

    {
      carbs: (food_macros[:carbohydrates] || 0) * multiplier,
      protein: (food_macros[:protein] || 0) * multiplier,
      fat: (food_macros[:fat] || 0) * multiplier
    }
  end

  def to_s
    "#{grams}g of #{food.description}"
  end
end
