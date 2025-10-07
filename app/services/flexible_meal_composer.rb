class FlexibleMealComposer
  # FlexibleMealComposer implements a meal composition algorithm using gradient descent optimization.
  #
  # Core Algorithm:
  # This service composes meals by iteratively optimizing food portions to meet target macronutrients.
  # Unlike the ThreeIngredientComposer, this class can handle any number of food categories.
  #
  # Mathematical Model:
  # For a meal with n ingredients, we need to solve:
  #   c₁p₁ + c₂p₂ + ... + cₙpₙ = target_carbs
  #   p₁p₁ + p₂p₂ + ... + pₙpₙ = target_protein
  #   f₁p₁ + f₂p₂ + ... + fₙpₙ = target_fat
  #
  # Where:
  # - cᵢ, pᵢ, fᵢ: carbohydrate, protein, and fat coefficients per gram for each food
  # - pᵢ: portion sizes in grams (our unknowns)
  # - target_carbs, target_protein, target_fat: nutritional targets
  #
  # When n > 3, the system is underdetermined with infinite solutions.
  # We optimize to find a practical solution that satisfies portion constraints.

  MACRO_TOLERANCE_GRAMS = 8.0  # Increased tolerance for faster convergence
  MIN_PORTION_SIZE = 10.0
  MAX_PORTION_SIZE = 500.0
  MAX_ITERATIONS = 200   # Reduced max iterations
  LEARNING_RATE = 0.5    # Increased learning rate
  PLATEAU_THRESHOLD = 0.01 # For early stopping

  # Define meal structure using category descriptions (can be customized)
  # All categories confirmed to exist in food_category.csv
  DEFAULT_MEAL_STRUCTURE = {
    breakfast: [ "Dairy and Egg Products", "Cereal Grains and Pasta",
                "Fruits and Fruit Juices", "Fats and Oils" ],
    lunch: [ "Poultry Products", "Vegetables and Vegetable Products",
            "Legumes and Legume Products", "Cereal Grains and Pasta", "Fats and Oils" ],
    dinner: [ "Beef Products", "Vegetables and Vegetable Products",
             "Cereal Grains and Pasta", "Fats and Oils", "Nut and Seed Products" ]
  }

  # Result classes to match ThreeIngredientComposer pattern
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

  def compose_daily_meals(macro_targets:, meal_structure: nil)
    Rails.logger.info("=== FlexibleMealComposer: Starting meal composition")
    Rails.logger.info("=== FlexibleMealComposer: Targets: carbs=#{macro_targets.carbs}, protein=#{macro_targets.protein}, fat=#{macro_targets.fat}")

    meal_structure ||= DEFAULT_MEAL_STRUCTURE
    category_structure = resolve_category_descriptions(meal_structure)

    # Distribute macros across meals
    meal_targets = distribute_macros_across_meals(macro_targets)
    Rails.logger.info("=== FlexibleMealComposer: Distributed targets across meals")

    composed_meals = {}
    remaining_targets = macro_targets.dup

    # Compose each meal
    [ :breakfast, :lunch, :dinner ].each do |meal_type|
      Rails.logger.info("=== FlexibleMealComposer: Composing #{meal_type} meal")
      Rails.logger.info("=== FlexibleMealComposer: #{meal_type} targets: carbs=#{meal_targets[meal_type].carbs}, protein=#{meal_targets[meal_type].protein}, fat=#{meal_targets[meal_type].fat}")

      meal_result = compose_single_meal(
        meal_targets: meal_targets[meal_type],
        meal_type: meal_type,
        category_ids: category_structure[meal_type],
        remaining_targets: remaining_targets
      )

      return Result.new(composed: false, error: "Failed to compose #{meal_type}") unless meal_result

      # Store the meal and update remaining targets
      composed_meals[meal_type] = meal_result

      # Adjust remaining targets
      meal_macros = calculate_meal_macros(meal_result.food_portions)
      remaining_targets.carbs -= meal_macros[:carbs]
      remaining_targets.protein -= meal_macros[:protein]
      remaining_targets.fat -= meal_macros[:fat]
    end

    # Calculate total actual macros for the day
    actual_macros = {
      carbs: composed_meals.values.sum { |meal| calculate_meal_macros(meal.food_portions)[:carbs] },
      protein: composed_meals.values.sum { |meal| calculate_meal_macros(meal.food_portions)[:protein] },
      fat: composed_meals.values.sum { |meal| calculate_meal_macros(meal.food_portions)[:fat] }
    }
    actual_macros_obj = MacroTargets.new(
      carbs: actual_macros[:carbs].round,
      protein: actual_macros[:protein].round,
      fat: actual_macros[:fat].round
    )

    Result.new(
      composed: true,
      daily_plan: DailyMealPlan.new(
        breakfast: composed_meals[:breakfast],
        lunch: composed_meals[:lunch],
        dinner: composed_meals[:dinner],
        target_macros: macro_targets,
        actual_macros: actual_macros_obj
      )
    )
  rescue StandardError => e
    Result.new(composed: false, error: "Composition error: #{e.message}")
  end

  private

  def resolve_category_descriptions(structure)
    resolved = {}

    structure.each do |meal_type, category_descriptions|
      resolved[meal_type] = category_descriptions.map do |description|
        category = FoodCategory.find_by(description: description)

        unless category
          raise "Unknown food category: #{description}"
        end

        category.id
      end
    end

    resolved
  end

  def distribute_macros_across_meals(macro_targets)
    {
      breakfast: MacroTargets.new(
        carbs: (macro_targets.carbs * 0.30).round,
        protein: (macro_targets.protein * 0.25).round,
        fat: (macro_targets.fat * 0.25).round
      ),
      lunch: MacroTargets.new(
        carbs: (macro_targets.carbs * 0.35).round,
        protein: (macro_targets.protein * 0.35).round,
        fat: (macro_targets.fat * 0.35).round
      ),
      dinner: MacroTargets.new(
        carbs: (macro_targets.carbs * 0.35).round,
        protein: (macro_targets.protein * 0.40).round,
        fat: (macro_targets.fat * 0.40).round
      )
    }
  end

  def compose_single_meal(meal_targets:, meal_type:, category_ids:, remaining_targets:)
    max_attempts = 10  # Reduced from 20 for faster processing
    attempts = 0
    Rails.logger.info("=== FlexibleMealComposer: Starting composition for #{meal_type} with #{category_ids.length} food categories")

    while attempts < max_attempts
      attempts += 1
      Rails.logger.info("=== FlexibleMealComposer: #{meal_type} - Attempt #{attempts}/#{max_attempts}")

      # Randomly select foods from each category (already filters for complete data)
      food_portions = randomly_select_foods_from_categories(category_ids)

      Rails.logger.info("=== FlexibleMealComposer: #{meal_type} - Attempt #{attempts} - Starting optimization")
      # Optimize portion sizes to meet macro targets
      if optimize_portions_iterative(food_portions, meal_targets)
        Rails.logger.info("=== FlexibleMealComposer: #{meal_type} - Success at attempt #{attempts}")
        # Calculate actual macros for the meal
        meal_macros = calculate_meal_macros(food_portions)
        # Convert hash to MacroTargets object
        macros_obj = MacroTargets.new(
          carbs: meal_macros[:carbs].round,
          protein: meal_macros[:protein].round,
          fat: meal_macros[:fat].round
        )
        return Meal.new(food_portions: food_portions, macros: macros_obj)
      else
        Rails.logger.info("=== FlexibleMealComposer: #{meal_type} - Attempt #{attempts} failed")
      end

      # If we've made several attempts and failed, try with relaxed constraints earlier
      if attempts >= max_attempts / 2
        Rails.logger.info("=== FlexibleMealComposer: #{meal_type} - Trying with relaxed constraints on attempt #{attempts}")
        if optimize_portions_iterative(food_portions, meal_targets, relaxed: true)
          Rails.logger.info("=== FlexibleMealComposer: #{meal_type} - Success with relaxed constraints")
          # Calculate actual macros for the meal
          meal_macros = calculate_meal_macros(food_portions)
          # Convert hash to MacroTargets object
          macros_obj = MacroTargets.new(
            carbs: meal_macros[:carbs].round,
            protein: meal_macros[:protein].round,
            fat: meal_macros[:fat].round
          )
          return Meal.new(food_portions: food_portions, macros: macros_obj)
        end
      end
    end

    # Last resort: try one more time with even more relaxed constraints
    Rails.logger.info("=== FlexibleMealComposer: #{meal_type} - Last attempt with very relaxed constraints")
    food_portions = randomly_select_foods_from_categories(category_ids)
    if optimize_portions_iterative(food_portions, meal_targets, relaxed: true, last_resort: true)
      Rails.logger.info("=== FlexibleMealComposer: #{meal_type} - Success with very relaxed constraints")
      # Calculate actual macros for the meal
      meal_macros = calculate_meal_macros(food_portions)
      # Convert hash to MacroTargets object
      macros_obj = MacroTargets.new(
        carbs: meal_macros[:carbs].round,
        protein: meal_macros[:protein].round,
        fat: meal_macros[:fat].round
      )
      return Meal.new(food_portions: food_portions, macros: macros_obj)
    end

    Rails.logger.info("=== FlexibleMealComposer: #{meal_type} - Failed to compose meal after all attempts")
    nil
  end

  def randomly_select_foods_from_categories(category_ids)
    food_portions = []

    category_ids.each do |category_id|
      # Pre-filter foods with complete macro data to avoid wasting attempts
      foods_with_nutrients = []
      attempt_count = 0
      max_filter_attempts = 10

      # Try to find foods with complete macro data
      while foods_with_nutrients.empty? && attempt_count < max_filter_attempts
        attempt_count += 1

        # Get a batch of random foods from this category
        random_foods = Food.where(food_category_id: category_id).order("RANDOM()").limit(5)

        if random_foods.empty?
          raise "No foods found for category ID #{category_id}"
        end

        # Filter those with complete macro data
        foods_with_nutrients = random_foods.select { |food| food_has_complete_macro_data?(food) }
      end

      if foods_with_nutrients.empty?
        # If we still don't have good foods after multiple attempts, just use any food
        # and hope for the best - it's better than failing completely
        selected_food = Food.where(food_category_id: category_id).order("RANDOM()").first
        Rails.logger.info("=== FlexibleMealComposer: Using food with incomplete data as last resort: #{selected_food.description}")
      else
        selected_food = foods_with_nutrients.sample
      end

      # Create a food portion with initial size of 0g (will be determined by optimization)
      food_portions << FoodPortion.new(food: selected_food, grams: 0)
    end

    food_portions
  end

  def optimize_portions_iterative(food_portions, targets, relaxed: false, last_resort: false)
    # Extract macro coefficients
    Rails.logger.info("=== FlexibleMealComposer: Optimization - Starting with #{food_portions.size} food items, relaxed=#{relaxed}")

    coefficients = food_portions.map do |portion|
      macros = NutrientLookupService.macronutrients_for(portion.food)
      {
        carbs: (macros[:carbohydrates] || 0) / 100.0,
        protein: (macros[:protein] || 0) / 100.0,
        fat: (macros[:fat] || 0) / 100.0
      }
    end

    food_portions.each_with_index do |portion, i|
      Rails.logger.info("=== FlexibleMealComposer: Food #{i+1}: #{portion.food.description} - C:#{coefficients[i][:carbs]*100}%, P:#{coefficients[i][:protein]*100}%, F:#{coefficients[i][:fat]*100}%")
    end

    # Start with equal portions totaling 300g
    n = food_portions.length
    start_grams = 300.0 / n
    portions = Array.new(n, start_grams)

    best_portions = portions.dup
    best_error = Float::INFINITY

    # Scale tolerance based on relaxation level
    tolerance = if last_resort
      MACRO_TOLERANCE_GRAMS * 4  # Very relaxed for last resort
    elsif relaxed
      MACRO_TOLERANCE_GRAMS * 2  # Moderately relaxed
    else
      MACRO_TOLERANCE_GRAMS      # Standard tolerance
    end

    iteration_count = 0

    MAX_ITERATIONS.times do |iter|
      iteration_count = iter + 1

      # Log progress every 100 iterations or at the beginning
      if iter == 0 || iter % 100 == 0 || iter == MAX_ITERATIONS - 1
        Rails.logger.info("=== FlexibleMealComposer: Optimization - Iteration #{iter+1}/#{MAX_ITERATIONS}")
      end

      # Calculate current macros
      current_carbs = portions.each_with_index.sum { |p, i| p * coefficients[i][:carbs] }
      current_protein = portions.each_with_index.sum { |p, i| p * coefficients[i][:protein] }
      current_fat = portions.each_with_index.sum { |p, i| p * coefficients[i][:fat] }

      # Calculate errors
      carb_error = targets.carbs - current_carbs
      protein_error = targets.protein - current_protein
      fat_error = targets.fat - current_fat

      total_error = carb_error**2 + protein_error**2 + fat_error**2

      # Save best solution
      if total_error < best_error
        best_error = total_error
        best_portions = portions.dup

        # Check if we're close enough
        if Math.sqrt(best_error) < tolerance
          break
        end
      end

      # Update portions based on gradient
      n.times do |i|
        gradient = 2 * (
          carb_error * coefficients[i][:carbs] +
          protein_error * coefficients[i][:protein] +
          fat_error * coefficients[i][:fat]
        )

        portions[i] += LEARNING_RATE * gradient

        # Constrain portions
        portions[i] = MIN_PORTION_SIZE if portions[i] < MIN_PORTION_SIZE
        portions[i] = MAX_PORTION_SIZE if portions[i] > MAX_PORTION_SIZE
      end
    end

    # Apply the best solution found
    food_portions.each_with_index do |portion, i|
      portion.grams = best_portions[i].round(1)
    end

    # Check if solution meets tolerance
    current_macros = calculate_meal_macros(food_portions)
    result = macros_within_tolerance?(current_macros, targets, tolerance)

    Rails.logger.info("=== FlexibleMealComposer: Optimization complete after #{iteration_count} iterations")
    Rails.logger.info("=== FlexibleMealComposer: Target macros: C:#{targets.carbs}g, P:#{targets.protein}g, F:#{targets.fat}g")
    Rails.logger.info("=== FlexibleMealComposer: Actual macros: C:#{current_macros[:carbs].round(1)}g, P:#{current_macros[:protein].round(1)}g, F:#{current_macros[:fat].round(1)}g")
    Rails.logger.info("=== FlexibleMealComposer: Portions: #{food_portions.map { |p| "#{p.food.description}: #{p.grams.round}g" }.join(', ')}")
    Rails.logger.info("=== FlexibleMealComposer: Solution #{result ? 'meets' : 'does not meet'} tolerance")

    result
  end

  def calculate_meal_macros(food_portions)
    totals = { carbs: 0, protein: 0, fat: 0 }

    food_portions.each do |portion|
      macros = NutrientLookupService.macronutrients_for(portion.food)

      # Convert from per 100g to actual amount
      conversion_factor = portion.grams / 100.0

      totals[:carbs] += (macros[:carbohydrates] || 0) * conversion_factor
      totals[:protein] += (macros[:protein] || 0) * conversion_factor
      totals[:fat] += (macros[:fat] || 0) * conversion_factor
    end

    totals
  end

  def macros_within_tolerance?(macros, targets, tolerance = MACRO_TOLERANCE_GRAMS)
    (macros[:carbs] - targets.carbs).abs <= tolerance &&
    (macros[:protein] - targets.protein).abs <= tolerance &&
    (macros[:fat] - targets.fat).abs <= tolerance
  end

  def food_has_complete_macro_data?(food)
    macros = NutrientLookupService.macronutrients_for(food)
    return false unless macros

    # Check if we have all the required macro values
    has_all_macros = [ :carbohydrates, :protein, :fat ].all? { |key| !macros[key].nil? }

    # Check if at least one macro has some nutritional value
    has_some_nutrition = (macros[:carbohydrates] || 0) > 0 ||
                         (macros[:protein] || 0) > 0 ||
                         (macros[:fat] || 0) > 0

    has_all_macros && has_some_nutrition
  end
end
