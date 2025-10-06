class ThreeIngredientComposer
  # ThreeIngredientComposer implements a meal composition algorithm using systems of linear equations.
  #
  # Core Algorithm:
  # This service composes meals by solving a system of linear equations to precisely determine
  # the optimal quantities of each food ingredient required to meet nutritional targets.
  #
  # Mathematical Model:
  # For each meal, we select exactly 3 food ingredients and set up the following system:
  #
  # | c₁ c₂ c₃ |   | p₁ |   | target_carbs   |
  # | p₁ p₂ p₃ | × | p₂ | = | target_protein |
  # | f₁ f₂ f₃ |   | p₃ |   | target_fat     |
  #
  # Where:
  # - c₁, c₂, c₃: carbohydrate coefficients per gram for each food
  # - p₁, p₂, p₃: protein coefficients per gram for each food
  # - f₁, f₂, f₃: fat coefficients per gram for each food
  # - p₁, p₂, p₃: portion sizes in grams (our unknowns)
  # - target_carbs, target_protein, target_fat: nutritional targets
  #
  # Solution Method:
  # We solve this system using Cramer's Rule, which is suitable for solving 3×3 systems efficiently.
  # Cramer's Rule calculates each unknown variable (portion size) as:
  #
  # p₁ = |A₁|/|A|, p₂ = |A₂|/|A|, p₃ = |A₃|/|A|
  #
  # Where:
  # - |A| is the determinant of the coefficient matrix
  # - |Aₙ| is the determinant of the matrix with the nth column replaced by the target vector
  #
  # Optimization Strategy:
  # If an exact solution doesn't exist or yields impractical portion sizes, we implement a
  # variation search within a predefined tolerance (±5g of each macro target). This increases
  # the probability of finding a viable solution while still meeting nutritional requirements
  # within an acceptable margin of error.
  #
  # The algorithm terminates when it finds portion sizes that:
  # 1. Are within practical limits (10g-500g per ingredient)
  # 2. Satisfy macro targets within specified tolerance
  # 3. Use exactly 3 ingredients per meal
  #
  # If no valid solution is found after 20 attempts, we consider the meal composition to have failed.
  #
  # Standard tolerance for 3 foods
  MACRO_TOLERANCE_GRAMS = 5.0

  # Define meal structure using category descriptions
  DEFAULT_MEAL_STRUCTURE = {
    breakfast: [ "Dairy and Egg Products", "Fats and Oils", "Fruits and Fruit Juices" ],
    lunch: [ "Poultry Products", "Fats and Oils", "Vegetables and Vegetable Products" ],
    dinner: [ "Beef Products", "Fats and Oils", "Vegetables and Vegetable Products" ]
  }.freeze

  def compose_daily_meals(macro_targets:, meal_structure: nil)
    structure = meal_structure || DEFAULT_MEAL_STRUCTURE

    invalid_meal = structure.find { |meal_type, categories| categories.length != 3 }
    if invalid_meal
      meal_name = invalid_meal[0]
      category_count = invalid_meal[1].length
      return Result.new(
        composed: false,
        error: "ThreeIngredientComposer requires exactly 3 food categories per meal. #{meal_name} has #{category_count}."
      )
    end

    resolved_structure = resolve_category_descriptions(structure)
    meal_targets = distribute_macros_across_meals(macro_targets)
    composed_meals = {}
    remaining_targets = macro_targets.dup

    [ :breakfast, :lunch, :dinner ].each do |meal_type|
      meal_result = compose_single_meal(
        meal_targets: meal_targets[meal_type],
        meal_type: meal_type,
        category_ids: resolved_structure[meal_type],
        remaining_targets: remaining_targets
      )

      return Result.new(composed: false, error: meal_result.error) unless meal_result.composed?

      composed_meals[meal_type] = meal_result.meal
      subtract_macros_from_remaining(remaining_targets, meal_result.meal.macros)
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

  def resolve_category_descriptions(structure)
    resolved = {}

    # Create a cache of descriptions to IDs for efficiency
    category_mapping = {}
    FoodCategory.all.each do |category|
      category_mapping[category.description] = category.id
    end

    structure.each do |meal_type, descriptions|
      # Look up the category IDs from the descriptions
      category_ids = descriptions.map do |description|
        category_mapping[description]
      end.compact

      resolved[meal_type] = category_ids unless category_ids.empty?
    end

    resolved
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

  def compose_single_meal(meal_targets:, meal_type:, category_ids:, remaining_targets:)
    Rails.logger.info("=== TEMP: Starting meal composition for #{meal_type} with #{category_ids.length} categories: #{category_ids}")
    Rails.logger.info("=== TEMP: Targets for this meal: carbs=#{meal_targets.carbs}g, protein=#{meal_targets.protein}g, fat=#{meal_targets.fat}g")

    20.times do |attempt|
      Rails.logger.info("=== TEMP: Attempt #{attempt+1} for #{meal_type}")
      selected_foods = randomly_select_foods_from_categories(category_ids)

      if selected_foods.length < category_ids.length || selected_foods.length != 3
        Rails.logger.info("=== TEMP: Failed to select enough foods, trying again")
        next
      end

      food_names = selected_foods.map { |fp| fp.food.description }
      Rails.logger.info("=== TEMP: Selected foods: #{food_names}")

      # Try to solve for exact portions using linear algebra
      if optimize_portions_for_targets(selected_foods, meal_targets)
        meal_macros = calculate_meal_macros(selected_foods)
        return SingleMealResult.new(
          composed: true,
          meal: Meal.new(food_portions: selected_foods, macros: meal_macros)
        )
      end
    end

    Rails.logger.info("=== TEMP: FAILED after 20 attempts for #{meal_type}")
    Rails.logger.info("=== TEMP: Reason for failure: Could not find foods that could be optimized to meet targets")

    SingleMealResult.new(
      composed: false,
      error: "Could not find valid food combination after 20 attempts for meal type: #{meal_type} with #{category_ids.length} food categories"
    )
  end

  def randomly_select_foods_from_categories(category_ids)
    selected_foods = []

    category_ids.each do |category_id|
      category = FoodCategory.find_by(id: category_id)
      category_name = category ? category.description : "Category #{category_id}"

      Rails.logger.info("=== TEMP: Looking for foods in category: #{category_name} (ID: #{category_id})")

      foods_in_category = Food.where(food_category_id: category_id)

      Rails.logger.info("=== TEMP: Found #{foods_in_category.count} foods in this category before filtering")

      # Filter for foods with complete macro data
      foods_with_macros = foods_in_category.select { |food| food_has_complete_macro_data?(food) }

      if foods_with_macros.empty?
        Rails.logger.info("=== TEMP: No foods with complete macro data in category #{category_name}, skipping")
        next
      end

      Rails.logger.info("=== TEMP: Found #{foods_with_macros.count} foods with complete macro data")

      # Simply pick one at random
      selected_food = foods_with_macros.sample
      Rails.logger.info("=== TEMP: Selected '#{selected_food.description}' from category #{category_name}")

      selected_foods << FoodPortion.new(food: selected_food, grams: 50.0) # Start with 50g
    end

    Rails.logger.info("=== TEMP: Total foods selected: #{selected_foods.length} out of #{category_ids.length} categories")
    selected_foods
  end

  def optimize_portions_for_targets(food_portions, targets)
    # Extract macro coefficients per gram for each food
    coefficients = food_portions.map do |portion|
      macros = NutrientLookupService.macronutrients_for(portion.food)
      coef = {
        carbs: (macros[:carbohydrates] || 0) / 100.0,
        protein: (macros[:protein] || 0) / 100.0,
        fat: (macros[:fat] || 0) / 100.0
      }
      coef
    end

    # This implementation is optimized for exactly 3 foods
    optimize_with_exact_solution(food_portions, targets, coefficients)
  end

  def optimize_with_exact_solution(food_portions, targets, coefficients)
    # Try different target variations within tolerance to find a valid solution
    target_variations = generate_target_variations(targets)

    target_variations.each do |target_variant|
      # Set up system: coefficients * portions = targets
      # [c1 c2 c3] [p1]   [target_carbs]
      # [p1 p2 p3] [p2] = [target_protein]
      # [f1 f2 f3] [p3]   [target_fat]
      matrix = [
        [ coefficients[0][:carbs], coefficients[1][:carbs], coefficients[2][:carbs] ],
        [ coefficients[0][:protein], coefficients[1][:protein], coefficients[2][:protein] ],
        [ coefficients[0][:fat], coefficients[1][:fat], coefficients[2][:fat] ]
      ]

      target_vector = [ target_variant[:carbs], target_variant[:protein], target_variant[:fat] ]

      # Solve using Gaussian elimination or matrix inversion
      solution = solve_linear_system(matrix, target_vector)

      if solution && solution.all? { |portion| portion >= 10.0 && portion <= 500.0 }
        # Apply the solution to the food portions
        food_portions.each_with_index do |portion, index|
          portion.grams = solution[index]
        end

        # Verify that the solution actually meets the targets
        current_macros = calculate_meal_macros(food_portions)

        if macros_within_tolerance?(current_macros, targets)
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

  def subtract_macros_from_remaining(remaining, meal)
    remaining.carbs -= meal.carbs
    remaining.protein -= meal.protein
    remaining.fat -= meal.fat
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
          # Skip the exact match since we already added it
          next if carb_offset == 0 && protein_offset == 0 && fat_offset == 0

          variations << {
            carbs: targets.carbs + carb_offset,
            protein: targets.protein + protein_offset,
            fat: targets.fat + fat_offset
          }
        end
      end
    end

    variations
  end

  def macros_within_tolerance?(actual, targets, use_relaxed_tolerance = false)
    carb_diff = (actual.carbs - targets.carbs).abs
    protein_diff = (actual.protein - targets.protein).abs
    fat_diff = (actual.fat - targets.fat).abs

    # Use standard tolerance for 3 foods
    tolerance = MACRO_TOLERANCE_GRAMS

    within_tolerance = carb_diff <= tolerance &&
                     protein_diff <= tolerance &&
                     fat_diff <= tolerance

    unless within_tolerance
      Rails.logger.info("=== TEMP: Not within tolerance - Differences: carbs=#{carb_diff}g (max #{tolerance}), " +
                      "protein=#{protein_diff}g (max #{tolerance}), " +
                      "fat=#{fat_diff}g (max #{tolerance})")
    end

    within_tolerance
  end

  # Result classes
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
