class SimpleMealComposer
  MACRO_TOLERANCE_GRAMS = 15.0

  # Same meal categories as DailyMealComposer for consistency
  DEFAULT_MEAL_CATEGORIES = {
    breakfast: [ 1, 4, 9 ],    # Dairy/eggs + cooking fats + fruits
    lunch: [ 5, 4, 11 ],       # Poultry + cooking fats + vegetables
    dinner: [ 13, 4, 11 ]      # Beef + cooking fats + vegetables
  }.freeze

  # Ensure each meal has at least one from each required category type
  REQUIRED_CATEGORIES_PER_MEAL = {
    breakfast: { dairy: [ 1 ], fat: [ 4 ], fruit: [ 9 ] },
    lunch: { poultry: [ 5 ], fat: [ 4 ], vegetable: [ 11 ] },
    dinner: { beef: [ 13 ], fat: [ 4 ], vegetable: [ 11 ] }
  }.freeze

  def compose_daily_meals(macro_targets:, meal_preferences: nil)
    preferences = meal_preferences || build_default_preferences

    # Distribute macros evenly across 3 meals
    meal_targets = distribute_macros_across_meals(macro_targets)

    composed_meals = {}
    remaining_targets = macro_targets.dup

    [ :breakfast, :lunch, :dinner ].each do |meal_type|
      allowed_categories = preferences.categories_for_meal(meal_type)
      meal_result = compose_single_meal(meal_targets[meal_type], allowed_categories, remaining_targets)

      return Result.new(composed: false, error: meal_result.error) unless meal_result.composed?

      composed_meals[meal_type] = meal_result.meal
      subtract_macros_from_remaining(remaining_targets, meal_result.meal)
    end

    actual_macros = calculate_total_macros(composed_meals)

    Result.new(
      composed: true,
      daily_plan: DailyMealPlan.new(
        breakfast: composed_meals[:breakfast],
        lunch: composed_meals[:lunch],
        dinner: composed_meals[:dinner],
        target_macros: macro_targets,
        actual_macros: actual_macros
      )
    )
  end

  private

  def build_default_preferences
    MealPreferences.new(
      breakfast_categories: DEFAULT_MEAL_CATEGORIES[:breakfast],
      lunch_categories: DEFAULT_MEAL_CATEGORIES[:lunch],
      dinner_categories: DEFAULT_MEAL_CATEGORIES[:dinner]
    )
  end

  def distribute_macros_across_meals(macro_targets)
    {
      breakfast: MacroTargets.new(
        carbs: macro_targets.carbs / 3.0,
        protein: macro_targets.protein / 3.0,
        fat: macro_targets.fat / 3.0
      ),
      lunch: MacroTargets.new(
        carbs: macro_targets.carbs / 3.0,
        protein: macro_targets.protein / 3.0,
        fat: macro_targets.fat / 3.0
      ),
      dinner: MacroTargets.new(
        carbs: macro_targets.carbs / 3.0,
        protein: macro_targets.protein / 3.0,
        fat: macro_targets.fat / 3.0
      )
    }
  end

  def compose_single_meal(meal_targets, allowed_categories, remaining_targets)
    meal_type = determine_meal_type(allowed_categories)
    required_categories = REQUIRED_CATEGORIES_PER_MEAL[meal_type]

    # Try up to 10 times to find a valid combination
    10.times do
      selected_foods = randomly_select_foods(required_categories)
      next if selected_foods.empty?

      # Try to solve for exact portions using linear algebra
      if optimize_portions_for_targets(selected_foods, meal_targets)
        current_macros = calculate_meal_macros(selected_foods)
        return SingleMealResult.new(
          composed: true,
          meal: Meal.new(food_portions: selected_foods, macros: current_macros)
        )
      end
    end

    SingleMealResult.new(
      composed: false,
      error: "Could not find valid food combination after 10 attempts"
    )
  end

  def randomly_select_foods(required_categories)
    selected_foods = []

    required_categories.each do |macro_type, category_ids|
      foods_in_category = Food.joins(:food_category)
                             .where(food_category_id: category_ids)
                             .includes(:food_nutrients, :nutrients)
                             .select { |food| food_has_complete_macro_data?(food) }

      next if foods_in_category.empty?

      # Simply pick one at random
      selected_food = foods_in_category.sample
      selected_foods << FoodPortion.new(food: selected_food, grams: 50.0) # Start with 50g
    end

    selected_foods
  end

  def optimize_portions_for_targets(food_portions, targets)
    return false if food_portions.length != 3 # Need exactly 3 foods for 3 macro targets

    # Extract macro coefficients per gram for each food
    coefficients = food_portions.map do |portion|
      macros = NutrientLookupService.macronutrients_for(portion.food)
      [
        (macros[:carbohydrates] || 0) / 100.0,  # carbs per gram
        (macros[:protein] || 0) / 100.0,        # protein per gram
        (macros[:fat] || 0) / 100.0             # fat per gram
      ]
    end

    # Try different target variations within tolerance to find a valid solution
    target_variations = generate_target_variations(targets)

    target_variations.each do |target_variant|
      # Set up system: coefficients * portions = targets
      # [c1 c2 c3] [p1]   [target_carbs]
      # [p1 p2 p3] [p2] = [target_protein]
      # [f1 f2 f3] [p3]   [target_fat]
      matrix = [
        [ coefficients[0][0], coefficients[1][0], coefficients[2][0] ], # carbs
        [ coefficients[0][1], coefficients[1][1], coefficients[2][1] ], # protein
        [ coefficients[0][2], coefficients[1][2], coefficients[2][2] ]  # fat
      ]

      target_vector = [ target_variant[:carbs], target_variant[:protein], target_variant[:fat] ]

      # Solve using Gaussian elimination or matrix inversion
      solution = solve_linear_system(matrix, target_vector)

      if solution && solution.all? { |portion| portion > 10 && portion < 500 } # Reasonable portions
        food_portions.each_with_index { |fp, i| fp.grams = solution[i] }

        # Verify the solution is within tolerance of original targets
        actual_macros = calculate_meal_macros(food_portions)
        if macros_within_tolerance?(actual_macros, targets)
          return true
        end
      end
    end

    false
  end

  def solve_linear_system(matrix, target)
    # Simple 3x3 matrix solver using Cramer's rule
    det = determinant_3x3(matrix)
    return nil if det.abs < 0.001 # Singular matrix

    # Solve for each variable using Cramer's rule
    solution = []
    3.times do |i|
      modified_matrix = matrix.map(&:dup)
      modified_matrix.each_with_index { |row, j| row[i] = target[j] }
      solution << determinant_3x3(modified_matrix) / det
    end

    solution
  end

  def determinant_3x3(matrix)
    a, b, c = matrix[0]
    d, e, f = matrix[1]
    g, h, i = matrix[2]

    a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)
  end

  def calculate_meal_macros(food_portions)
    total_carbs = food_portions.sum do |fp|
      macros = NutrientLookupService.macronutrients_for(fp.food)
      ((macros[:carbohydrates] || 0) * fp.grams / 100.0)
    end

    total_protein = food_portions.sum do |fp|
      macros = NutrientLookupService.macronutrients_for(fp.food)
      ((macros[:protein] || 0) * fp.grams / 100.0)
    end

    total_fat = food_portions.sum do |fp|
      macros = NutrientLookupService.macronutrients_for(fp.food)
      ((macros[:fat] || 0) * fp.grams / 100.0)
    end

    MacroTargets.new(carbs: total_carbs, protein: total_protein, fat: total_fat)
  end

  def food_has_complete_macro_data?(food)
    macros = NutrientLookupService.macronutrients_for(food)

    # Must have at least carbs OR protein OR fat data (some foods are zero in some macros)
    has_some_nutrition = macros[:carbohydrates] || macros[:protein] || macros[:fat]

    has_some_nutrition
  end

  def determine_meal_type(allowed_categories)
    # Simple mapping based on category combinations
    return :breakfast if allowed_categories.include?(1) && allowed_categories.include?(9) # dairy + fruit
    return :lunch if allowed_categories.include?(5) # poultry
    return :dinner if allowed_categories.include?(13) # beef

    :breakfast # fallback
  end

  def subtract_macros_from_remaining(remaining, meal)
    remaining.carbs -= meal.macros.carbs
    remaining.protein -= meal.macros.protein
    remaining.fat -= meal.macros.fat
  end

  def calculate_total_macros(composed_meals)
    total_carbs = composed_meals.values.sum { |meal| meal.macros.carbs }
    total_protein = composed_meals.values.sum { |meal| meal.macros.protein }
    total_fat = composed_meals.values.sum { |meal| meal.macros.fat }

    MacroTargets.new(carbs: total_carbs, protein: total_protein, fat: total_fat)
  end

  def generate_target_variations(targets)
    # Generate variations within tolerance to increase chances of finding a solution
    variations = []

    # Try exact targets first
    variations << { carbs: targets.carbs, protein: targets.protein, fat: targets.fat }

    # Try variations within tolerance (±MACRO_TOLERANCE_GRAMS)
    [ -MACRO_TOLERANCE_GRAMS, 0, MACRO_TOLERANCE_GRAMS ].each do |carb_offset|
      [ -MACRO_TOLERANCE_GRAMS, 0, MACRO_TOLERANCE_GRAMS ].each do |protein_offset|
        [ -MACRO_TOLERANCE_GRAMS, 0, MACRO_TOLERANCE_GRAMS ].each do |fat_offset|
          # Skip the exact target (already added above)
          next if carb_offset == 0 && protein_offset == 0 && fat_offset == 0

          variations << {
            carbs: [ targets.carbs + carb_offset, 0 ].max, # Don't go below 0
            protein: [ targets.protein + protein_offset, 0 ].max,
            fat: [ targets.fat + fat_offset, 0 ].max
          }
        end
      end
    end

    variations
  end

  def macros_within_tolerance?(actual, targets)
    (actual.carbs - targets.carbs).abs <= MACRO_TOLERANCE_GRAMS &&
    (actual.protein - targets.protein).abs <= MACRO_TOLERANCE_GRAMS &&
    (actual.fat - targets.fat).abs <= MACRO_TOLERANCE_GRAMS
  end

  # Result classes - reusing the same structure as DailyMealComposer
  class Result
    attr_reader :daily_plan, :error

    def initialize(composed:, daily_plan: nil, error: nil)
      @composed = composed
      @daily_plan = daily_plan
      @error = error
    end

    def composed?
      @composed
    end
  end

  class SingleMealResult
    attr_reader :meal, :error

    def initialize(composed:, meal: nil, error: nil)
      @composed = composed
      @meal = meal
      @error = error
    end

    def composed?
      @composed
    end
  end
end
