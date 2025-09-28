class DailyMealPlan
  attr_reader :breakfast, :lunch, :dinner, :target_macros, :actual_macros

  def initialize(breakfast:, lunch:, dinner:, target_macros:, actual_macros:)
    @breakfast = breakfast
    @lunch = lunch
    @dinner = dinner
    @target_macros = target_macros
    @actual_macros = actual_macros
  end

  def within_tolerance?
    tolerance = DailyMealComposer::MACRO_TOLERANCE_GRAMS

    (actual_macros.carbs - target_macros.carbs).abs <= tolerance &&
    (actual_macros.protein - target_macros.protein).abs <= tolerance &&
    (actual_macros.fat - target_macros.fat).abs <= tolerance
  end

  def total_foods
    breakfast.food_count + lunch.food_count + dinner.food_count
  end

  def total_grams
    breakfast.total_grams + lunch.total_grams + dinner.total_grams
  end

  def macro_differences
    {
      carbs: actual_macros.carbs - target_macros.carbs,
      protein: actual_macros.protein - target_macros.protein,
      fat: actual_macros.fat - target_macros.fat
    }
  end
end
