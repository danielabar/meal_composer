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
    tolerance = ::FlexibleMealComposer::MACRO_TOLERANCE_GRAMS

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

  def pretty_print
    output = []
    output << "Plan uses #{total_foods} foods totaling #{total_grams}g"

    output << "\n=== BREAKFAST ==="
    breakfast.food_portions.each do |portion|
      output << "#{portion.grams.round(1)}g of #{portion.food.description}"
    end
    output << "Breakfast macros: carbs=#{breakfast.macros.carbs.round(1)}g, protein=#{breakfast.macros.protein.round(1)}g, fat=#{breakfast.macros.fat.round(1)}g"

    output << "\n=== LUNCH ==="
    lunch.food_portions.each do |portion|
      output << "#{portion.grams.round(1)}g of #{portion.food.description}"
    end
    output << "Lunch macros: carbs=#{lunch.macros.carbs.round(1)}g, protein=#{lunch.macros.protein.round(1)}g, fat=#{lunch.macros.fat.round(1)}g"

    output << "\n=== DINNER ==="
    dinner.food_portions.each do |portion|
      output << "#{portion.grams.round(1)}g of #{portion.food.description}"
    end
    output << "Dinner macros: carbs=#{dinner.macros.carbs.round(1)}g, protein=#{dinner.macros.protein.round(1)}g, fat=#{dinner.macros.fat.round(1)}g"

    output << "\n=== DAILY TOTALS ==="
    output << "Target: #{target_macros}"
    output << "Actual: #{actual_macros}"
    differences = macro_differences
    output << "Difference: carbs #{differences[:carbs].round(1)}g, protein #{differences[:protein].round(1)}g, fat #{differences[:fat].round(1)}g"
    output << "Within tolerance: #{within_tolerance?}"

    output.join("\n")
  end
end
