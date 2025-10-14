class Meal
  attr_reader :food_portions, :macros

  def initialize(food_portions:, macros:)
    @food_portions = food_portions
    @macros = macros
  end

  def total_grams
    food_portions.sum(&:grams)
  end

  def food_count
    food_portions.count
  end

  def to_s
    portions_text = food_portions.map(&:to_s).join(", ")
    "Meal: #{portions_text} (#{macros})"
  end
end
