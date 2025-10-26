class MealPlanGenerator
  # MealPlanGenerator implements meal composition using gradient descent optimization.
  # This is the production service that works with ActiveRecord models.
  #
  # Input: AR models (User, DailyMacroTarget, DailyMealStructure, name)
  # Output: AR models (DailyMealPlan with associated Meals and FoodPortions)
  #
  # Core algorithm adapted from FlexibleMealComposer POC

  MACRO_TOLERANCE_GRAMS = 8.0
  MIN_PORTION_SIZE = 10.0
  MAX_PORTION_SIZE = 500.0
  MAX_ITERATIONS = 50
  LEARNING_RATE = 0.5

  # Result object to return from the service
  Result = Struct.new(:success?, :daily_meal_plan, :error, keyword_init: true)

  # Temporary struct to hold food + grams during optimization
  FoodWithGrams = Struct.new(:food, :grams, keyword_init: true) do
    def grams=(new_grams)
      self[:grams] = new_grams
    end
  end

  def initialize(user:, name:, daily_macro_target:, daily_meal_structure:)
    @user = user
    @name = name
    @daily_macro_target = daily_macro_target
    @daily_meal_structure = daily_meal_structure
    @failure_message = nil  # Store detailed failure diagnostics
  end

  def generate
    Rails.logger.info("=== MealPlanGenerator: Starting generation for user #{@user.id}")
    Rails.logger.info("=== MealPlanGenerator: Targets: #{@daily_macro_target.carbs_grams}g C, #{@daily_macro_target.protein_grams}g P, #{@daily_macro_target.fat_grams}g F")

    composition_result = compose_meals

    if composition_result.nil?
      error_msg = @failure_message || "Unable to compose meals with selected foods and macro targets"
      return Result.new(success?: false, error: error_msg)
    end

    # Calculate total actual macros
    actual_carbs = composition_result[:actual_carbs]
    actual_protein = composition_result[:actual_protein]
    actual_fat = composition_result[:actual_fat]

    # Persist to database
    daily_meal_plan = persist_meal_plan(composition_result[:composed_meals], actual_carbs, actual_protein, actual_fat)

    Result.new(success?: true, daily_meal_plan: daily_meal_plan)
  rescue StandardError => e
    Rails.logger.error("MealPlanGenerator failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    Result.new(success?: false, error: "An unexpected error occurred: #{e.message}")
  end

  # Public method to compose meals without persisting
  # Returns hash with :composed_meals, :actual_carbs, :actual_protein, :actual_fat
  # or nil if composition fails
  def compose_meals
    Rails.logger.info("=== MealPlanGenerator: Composing meals for user #{@user.id}")

    # Try to compose meals that meet daily tolerance requirement
    max_daily_attempts = 5
    max_daily_attempts.times do |daily_attempt|
      Rails.logger.info("=== MealPlanGenerator: Daily composition attempt #{daily_attempt + 1}/#{max_daily_attempts}")

      # Distribute daily macros across meals
      meal_targets = distribute_macros_across_meals

      # Compose each meal
      composed_meals = {}
      all_meals_composed = true

      get_meal_labels.each do |meal_label|
        meal_type = meal_label.to_sym
        Rails.logger.info("=== MealPlanGenerator: Composing #{meal_type}")

        meal_result = compose_single_meal(
          meal_type: meal_type,
          target_carbs: meal_targets[meal_type][:carbs],
          target_protein: meal_targets[meal_type][:protein],
          target_fat: meal_targets[meal_type][:fat]
        )

        unless meal_result
          Rails.logger.error("Failed to compose #{meal_type} meal after multiple attempts")
          all_meals_composed = false
          break
        end

        composed_meals[meal_type] = meal_result
      end

      # If any meal failed to compose, try again
      next unless all_meals_composed

      # Calculate total actual macros
      actual_carbs = composed_meals.values.sum { |m| m[:actual_carbs] }
      actual_protein = composed_meals.values.sum { |m| m[:actual_protein] }
      actual_fat = composed_meals.values.sum { |m| m[:actual_fat] }

      # CRITICAL: Validate daily totals against daily tolerance (business requirement)
      daily_carb_diff = (actual_carbs - daily_macro_target.carbs_grams).abs
      daily_protein_diff = (actual_protein - daily_macro_target.protein_grams).abs
      daily_fat_diff = (actual_fat - daily_macro_target.fat_grams).abs

      daily_within_tolerance = daily_carb_diff <= MACRO_TOLERANCE_GRAMS &&
                               daily_protein_diff <= MACRO_TOLERANCE_GRAMS &&
                               daily_fat_diff <= MACRO_TOLERANCE_GRAMS

      # PHASE 2: If daily totals exceed tolerance, try adjusting portions before giving up
      unless daily_within_tolerance
        Rails.logger.info("=== Phase 2: Attempting daily adjustment to fix deviations")
        adjusted = adjust_portions_for_daily_targets(
          composed_meals,
          daily_macro_target.carbs_grams,
          daily_macro_target.protein_grams,
          daily_macro_target.fat_grams
        )

        if adjusted
          # Recalculate after adjustment
          actual_carbs = composed_meals.values.sum { |m| m[:actual_carbs] }
          actual_protein = composed_meals.values.sum { |m| m[:actual_protein] }
          actual_fat = composed_meals.values.sum { |m| m[:actual_fat] }

          daily_carb_diff = (actual_carbs - daily_macro_target.carbs_grams).abs
          daily_protein_diff = (actual_protein - daily_macro_target.protein_grams).abs
          daily_fat_diff = (actual_fat - daily_macro_target.fat_grams).abs

          daily_within_tolerance = daily_carb_diff <= MACRO_TOLERANCE_GRAMS &&
                                   daily_protein_diff <= MACRO_TOLERANCE_GRAMS &&
                                   daily_fat_diff <= MACRO_TOLERANCE_GRAMS

          Rails.logger.info("=== Phase 2 #{daily_within_tolerance ? 'SUCCESS' : 'did not achieve tolerance'}")
        else
          Rails.logger.info("=== Phase 2 adjustment not possible with current constraints")
        end
      end

      Rails.logger.info("=== Daily totals: C:#{actual_carbs.round(1)}g (#{daily_carb_diff.round(1)}g diff), " \
                       "P:#{actual_protein.round(1)}g (#{daily_protein_diff.round(1)}g diff), " \
                       "F:#{actual_fat.round(1)}g (#{daily_fat_diff.round(1)}g diff) - " \
                       "#{daily_within_tolerance ? 'MEETS DAILY TOLERANCE' : 'EXCEEDS DAILY TOLERANCE'}")

      if daily_within_tolerance
        # Success! Return the composed meals
        return {
          composed_meals: composed_meals,
          actual_carbs: actual_carbs,
          actual_protein: actual_protein,
          actual_fat: actual_fat
        }
      else
        Rails.logger.warn("=== Daily totals exceed tolerance (±#{MACRO_TOLERANCE_GRAMS}g), retrying with different food selections...")
      end
    end

    # Failed after all daily attempts
    Rails.logger.error("=== Failed to compose meal plan within daily tolerance after #{max_daily_attempts} attempts")
    nil
  rescue StandardError => e
    Rails.logger.error("MealPlanGenerator#compose_meals failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    nil
  end

  private

  attr_reader :user, :name, :daily_macro_target, :daily_meal_structure

  # Distribute daily macros across meals evenly
  # TODO: Future feature - allow users to specify custom distribution percentages instead of even split
  def distribute_macros_across_meals
    meal_labels = get_meal_labels
    percentage_per_meal = 1.0 / meal_labels.count

    result = {}
    meal_labels.each do |label|
      result[label.to_sym] = {
        carbs: (daily_macro_target.carbs_grams * percentage_per_meal).round,
        protein: (daily_macro_target.protein_grams * percentage_per_meal).round,
        fat: (daily_macro_target.fat_grams * percentage_per_meal).round
      }
    end

    result
  end

  # Compose a single meal by selecting foods and optimizing portions
  def compose_single_meal(meal_type:, target_carbs:, target_protein:, target_fat:)
    # Get meal structure item for this meal
    meal_structure_item = daily_meal_structure.meal_structure_items.find_by(meal_label: meal_type.to_s)
    unless meal_structure_item
      Rails.logger.error("No meal structure item found for #{meal_type}")
      return nil
    end

    # Calculate per-meal tolerance distributed from daily tolerance
    num_meals = get_meal_labels.count
    per_meal_convergence_tolerance = MACRO_TOLERANCE_GRAMS / (2.0 * num_meals)
    per_meal_acceptance_tolerance = MACRO_TOLERANCE_GRAMS / num_meals

    Rails.logger.info("=== Per-meal tolerances: convergence ±#{per_meal_convergence_tolerance.round(1)}g, " \
                     "acceptance ±#{per_meal_acceptance_tolerance.round(1)}g (distributed from daily ±#{MACRO_TOLERANCE_GRAMS}g)")

    # Route based on meal's mode
    if meal_structure_item.mode == "food"
      Rails.logger.info("=== MealPlanGenerator: #{meal_type} - Using food-based mode")
      compose_meal_by_foods(meal_type, meal_structure_item, target_carbs, target_protein, target_fat,
                           per_meal_convergence_tolerance, per_meal_acceptance_tolerance)
    else
      Rails.logger.info("=== MealPlanGenerator: #{meal_type} - Using category-based mode")
      compose_meal_by_categories(meal_type, meal_structure_item, target_carbs, target_protein, target_fat,
                                 per_meal_convergence_tolerance, per_meal_acceptance_tolerance)
    end
  end

  # Compose meal using category-based selection (existing logic, extracted)
  def compose_meal_by_categories(meal_type, meal_structure_item, target_carbs, target_protein, target_fat,
                                  convergence_tolerance, acceptance_tolerance)
    category_ids = meal_structure_item.food_category_ids
    max_attempts = 10

    # Track best solution across all attempts
    best_foods = nil
    best_error = Float::INFINITY

    max_attempts.times do |attempt|
      Rails.logger.info("=== MealPlanGenerator: #{meal_type} - Attempt #{attempt + 1}/#{max_attempts}")

      # Randomly select one food from each category
      foods_with_grams = randomly_select_foods(category_ids)

      # Try to optimize portions with distributed tolerances
      if optimize_portions(foods_with_grams, target_carbs, target_protein, target_fat,
                          convergence_tolerance: convergence_tolerance,
                          acceptance_tolerance: acceptance_tolerance)
        Rails.logger.info("=== MealPlanGenerator: #{meal_type} - Success at attempt #{attempt + 1}")

        # Calculate actual macros
        actual_macros = calculate_macros(foods_with_grams)

        return {
          foods_with_grams: foods_with_grams,
          actual_carbs: actual_macros[:carbs],
          actual_protein: actual_macros[:protein],
          actual_fat: actual_macros[:fat]
        }
      end

      # Track best attempt even if it failed tolerance
      actual_macros = calculate_macros(foods_with_grams)
      error = (actual_macros[:carbs] - target_carbs)**2 +
              (actual_macros[:protein] - target_protein)**2 +
              (actual_macros[:fat] - target_fat)**2

      if error < best_error
        best_error = error
        best_foods = foods_with_grams.map { |f| FoodWithGrams.new(food: f.food, grams: f.grams) }
      end

      # Try with relaxed constraints after several attempts
      if attempt >= max_attempts / 2
        Rails.logger.info("=== MealPlanGenerator: #{meal_type} - Trying with relaxed constraints")
        if optimize_portions(foods_with_grams, target_carbs, target_protein, target_fat,
                            convergence_tolerance: convergence_tolerance * 2,
                            acceptance_tolerance: acceptance_tolerance * 2,
                            relaxed: true)
          Rails.logger.info("=== MealPlanGenerator: #{meal_type} - Success with relaxed constraints")
          actual_macros = calculate_macros(foods_with_grams)
          return {
            foods_with_grams: foods_with_grams,
            actual_carbs: actual_macros[:carbs],
            actual_protein: actual_macros[:protein],
            actual_fat: actual_macros[:fat]
          }
        end
      end
    end

    # Last resort with very relaxed constraints
    Rails.logger.info("=== MealPlanGenerator: #{meal_type} - Last attempt with very relaxed constraints")
    foods_with_grams = randomly_select_foods(category_ids)
    if optimize_portions(foods_with_grams, target_carbs, target_protein, target_fat,
                        convergence_tolerance: convergence_tolerance * 4,
                        acceptance_tolerance: acceptance_tolerance * 4,
                        last_resort: true)
      Rails.logger.info("=== MealPlanGenerator: #{meal_type} - Success with very relaxed constraints")
      actual_macros = calculate_macros(foods_with_grams)
      return {
        foods_with_grams: foods_with_grams,
        actual_carbs: actual_macros[:carbs],
        actual_protein: actual_macros[:protein],
        actual_fat: actual_macros[:fat]
      }
    end

    # FALLBACK: Return best attempt even if it didn't meet per-meal tolerance
    # Phase 2 will adjust portions across all meals to meet daily tolerance
    if best_foods
      actual_macros = calculate_macros(best_foods)
      Rails.logger.warn("=== MealPlanGenerator: #{meal_type} - Returning best attempt (error: #{Math.sqrt(best_error).round(1)}g) " \
                       "- Phase 2 will adjust for daily totals")
      return {
        foods_with_grams: best_foods,
        actual_carbs: actual_macros[:carbs],
        actual_protein: actual_macros[:protein],
        actual_fat: actual_macros[:fat]
      }
    end

    Rails.logger.error("=== MealPlanGenerator: #{meal_type} - Failed after all attempts (no solution found)")
    nil
  end

  # Compose meal using food-based selection (new logic)
  def compose_meal_by_foods(meal_type, meal_structure_item, target_carbs, target_protein, target_fat,
                            convergence_tolerance, acceptance_tolerance)
    food_ids = meal_structure_item.food_ids
    max_attempts = 10

    # Track best solution across all attempts
    best_foods = nil
    best_error = Float::INFINITY

    max_attempts.times do |attempt|
      Rails.logger.info("=== MealPlanGenerator: #{meal_type} - Food-based attempt #{attempt + 1}/#{max_attempts}")

      # Use explicit food selections instead of random selection
      foods_with_grams = prepare_selected_foods(food_ids)

      # Try to optimize portions with distributed tolerances
      if optimize_portions(foods_with_grams, target_carbs, target_protein, target_fat,
                          convergence_tolerance: convergence_tolerance,
                          acceptance_tolerance: acceptance_tolerance)
        Rails.logger.info("=== MealPlanGenerator: #{meal_type} - Food-based success at attempt #{attempt + 1}")

        # Calculate actual macros
        actual_macros = calculate_macros(foods_with_grams)

        return {
          foods_with_grams: foods_with_grams,
          actual_carbs: actual_macros[:carbs],
          actual_protein: actual_macros[:protein],
          actual_fat: actual_macros[:fat]
        }
      end

      # Track best attempt even if it failed tolerance
      actual_macros = calculate_macros(foods_with_grams)
      error = (actual_macros[:carbs] - target_carbs)**2 +
              (actual_macros[:protein] - target_protein)**2 +
              (actual_macros[:fat] - target_fat)**2

      if error < best_error
        best_error = error
        best_foods = foods_with_grams.map { |f| FoodWithGrams.new(food: f.food, grams: f.grams) }
      end

      # Try with relaxed constraints after several attempts
      if attempt >= max_attempts / 2
        Rails.logger.info("=== MealPlanGenerator: #{meal_type} - Food-based trying with relaxed constraints")
        if optimize_portions(foods_with_grams, target_carbs, target_protein, target_fat,
                            convergence_tolerance: convergence_tolerance * 2,
                            acceptance_tolerance: acceptance_tolerance * 2,
                            relaxed: true)
          Rails.logger.info("=== MealPlanGenerator: #{meal_type} - Food-based success with relaxed constraints")
          actual_macros = calculate_macros(foods_with_grams)
          return {
            foods_with_grams: foods_with_grams,
            actual_carbs: actual_macros[:carbs],
            actual_protein: actual_macros[:protein],
            actual_fat: actual_macros[:fat]
          }
        end
      end
    end

    # Last resort with very relaxed constraints
    Rails.logger.info("=== MealPlanGenerator: #{meal_type} - Food-based last attempt with very relaxed constraints")
    foods_with_grams = prepare_selected_foods(food_ids)
    if optimize_portions(foods_with_grams, target_carbs, target_protein, target_fat,
                        convergence_tolerance: convergence_tolerance * 4,
                        acceptance_tolerance: acceptance_tolerance * 4,
                        last_resort: true)
      Rails.logger.info("=== MealPlanGenerator: #{meal_type} - Food-based success with very relaxed constraints")
      actual_macros = calculate_macros(foods_with_grams)
      return {
        foods_with_grams: foods_with_grams,
        actual_carbs: actual_macros[:carbs],
        actual_protein: actual_macros[:protein],
        actual_fat: actual_macros[:fat]
      }
    end

    # FALLBACK: Return best attempt even if it didn't meet per-meal tolerance
    # Phase 2 will adjust portions across all meals to meet daily tolerance
    if best_foods
      actual_macros = calculate_macros(best_foods)
      Rails.logger.warn("=== MealPlanGenerator: #{meal_type} - Returning best attempt (error: #{Math.sqrt(best_error).round(1)}g) " \
                       "- Phase 2 will adjust for daily totals")
      return {
        foods_with_grams: best_foods,
        actual_carbs: actual_macros[:carbs],
        actual_protein: actual_macros[:protein],
        actual_fat: actual_macros[:fat]
      }
    end

    Rails.logger.error("=== MealPlanGenerator: #{meal_type} - Food-based failed after all attempts (no solution found)")
    nil
  end

  # Randomly select one food from each category
  def randomly_select_foods(category_ids)
    foods = []

    category_ids.each do |category_id|
      # Try to find food with complete macro data
      foods_with_nutrients = []
      max_filter_attempts = 10

      max_filter_attempts.times do
        random_foods = Food.where(food_category_id: category_id).order("RANDOM()").limit(5)

        if random_foods.empty?
          raise "No foods found for category ID #{category_id}"
        end

        foods_with_nutrients = random_foods.select { |food| food_has_complete_macro_data?(food) }
        break if foods_with_nutrients.any?
      end

      selected_food = if foods_with_nutrients.any?
        foods_with_nutrients.sample
      else
        # Last resort: use any food
        Food.where(food_category_id: category_id).order("RANDOM()").first
      end

      foods << FoodWithGrams.new(food: selected_food, grams: 0)
    end

    foods
  end

  # Prepare explicitly selected foods (food-based mode)
  def prepare_selected_foods(food_ids)
    foods = []

    food_ids.each do |food_id|
      food = Food.find(food_id)

      unless food_has_complete_macro_data?(food)
        Rails.logger.warn("=== MealPlanGenerator: Food #{food.description} (#{food_id}) has incomplete macro data")
      end

      foods << FoodWithGrams.new(food: food, grams: 0)
    end

    foods
  end

  # Check if food has complete macro data
  def food_has_complete_macro_data?(food)
    macros = NutrientLookupService.macronutrients_for(food)
    return false unless macros

    # Special case for oils/fats
    category = FoodCategory.find_by(id: food.food_category_id)
    if category && (category.description =~ /fat|oil/i)
      return !macros[:fat].nil? && macros[:fat] > 0
    end

    # Regular foods need all macros
    has_all_macros = [ :carbohydrates, :protein, :fat ].all? { |key| !macros[key].nil? }
    has_some_nutrition = (macros[:carbohydrates] || 0) > 0 ||
                        (macros[:protein] || 0) > 0 ||
                        (macros[:fat] || 0) > 0

    has_all_macros && has_some_nutrition
  end

  # Calculate dynamic weighted error based on proportional deficiency
  # Macros that are further off proportionally get higher weight
  def calculate_dynamic_weighted_error(carb_error, protein_error, fat_error,
                                       target_carbs, target_protein, target_fat)
    # Calculate proportional errors (what % of target are we off by?)
    carb_prop_error = target_carbs > 0 ? (carb_error.abs / target_carbs) : 0
    protein_prop_error = target_protein > 0 ? (protein_error.abs / target_protein) : 0
    fat_prop_error = target_fat > 0 ? (fat_error.abs / target_fat) : 0

    # Find the maximum proportional error
    max_prop_error = [ carb_prop_error, protein_prop_error, fat_prop_error ].max

    # Calculate weights: macro with highest proportional error gets weight 2.0,
    # others get weight proportional to their error (range 1.0 to 2.0)
    carb_weight = max_prop_error > 0 ? (1.0 + carb_prop_error / max_prop_error) : 1.0
    protein_weight = max_prop_error > 0 ? (1.0 + protein_prop_error / max_prop_error) : 1.0
    fat_weight = max_prop_error > 0 ? (1.0 + fat_prop_error / max_prop_error) : 1.0

    # Calculate weighted squared error
    (carb_weight * carb_error**2) +
    (protein_weight * protein_error**2) +
    (fat_weight * fat_error**2)
  end

  # Calculate dynamic weighted gradient for a specific food
  # Uses same weights as error function to prioritize deficient macros
  def calculate_dynamic_weighted_gradient(i, carb_error, protein_error, fat_error,
                                         coefficients, target_carbs, target_protein, target_fat)
    # Calculate proportional errors (same as in error function)
    carb_prop_error = target_carbs > 0 ? (carb_error.abs / target_carbs) : 0
    protein_prop_error = target_protein > 0 ? (protein_error.abs / target_protein) : 0
    fat_prop_error = target_fat > 0 ? (fat_error.abs / target_fat) : 0

    max_prop_error = [ carb_prop_error, protein_prop_error, fat_prop_error ].max

    carb_weight = max_prop_error > 0 ? (1.0 + carb_prop_error / max_prop_error) : 1.0
    protein_weight = max_prop_error > 0 ? (1.0 + protein_prop_error / max_prop_error) : 1.0
    fat_weight = max_prop_error > 0 ? (1.0 + fat_prop_error / max_prop_error) : 1.0

    # Calculate weighted gradient
    2 * (
      carb_weight * carb_error * coefficients[i][:carbs] +
      protein_weight * protein_error * coefficients[i][:protein] +
      fat_weight * fat_error * coefficients[i][:fat]
    )
  end

  # Optimize portion sizes using gradient descent with multiple random restarts
  def optimize_portions(foods_with_grams, target_carbs, target_protein, target_fat,
                       convergence_tolerance:, acceptance_tolerance:, relaxed: false, last_resort: false, num_restarts: 5)
    best_error = Float::INFINITY
    best_foods = nil

    Rails.logger.info("=== Starting optimization with #{num_restarts} restarts")

    num_restarts.times do |restart|
      Rails.logger.info("=== Optimization restart #{restart + 1}/#{num_restarts}")

      # Create fresh copy of foods for this attempt
      test_foods = foods_with_grams.map { |f| FoodWithGrams.new(food: f.food, grams: 0) }

      # Run single optimization attempt
      success = optimize_portions_once(
        test_foods, target_carbs, target_protein, target_fat,
        convergence_tolerance: convergence_tolerance,
        acceptance_tolerance: acceptance_tolerance,
        relaxed: relaxed,
        last_resort: last_resort,
        restart_seed: restart
      )

      # Calculate error for this solution (whether it passed tolerance or not)
      actual_macros = calculate_macros(test_foods)
      carb_error = target_carbs - actual_macros[:carbs]
      protein_error = target_protein - actual_macros[:protein]
      fat_error = target_fat - actual_macros[:fat]
      current_error = carb_error**2 + protein_error**2 + fat_error**2

      if success
        Rails.logger.info("=== Restart #{restart + 1} SUCCESS with error: #{current_error.round(2)} " \
                         "(C:#{carb_error.round(1)}g P:#{protein_error.round(1)}g F:#{fat_error.round(1)}g)")
      else
        Rails.logger.info("=== Restart #{restart + 1} FAILED tolerance but achieved error: #{current_error.round(2)} " \
                         "(C:#{carb_error.round(1)}g P:#{protein_error.round(1)}g F:#{fat_error.round(1)}g)")
      end

      # Keep best solution even if it failed tolerance - it's still better than nothing
      if current_error < best_error
        best_error = current_error
        best_foods = test_foods
        Rails.logger.info("=== New best solution found at restart #{restart + 1} (within tolerance: #{success})")
      end
    end

    # We should always have a best solution (even if all restarts failed tolerance)
    if best_foods
      foods_with_grams.each_with_index do |item, i|
        item.grams = best_foods[i].grams
      end
      Rails.logger.info("=== Using best solution from #{num_restarts} restarts with error: #{best_error.round(2)}")

      # Check if this best solution meets acceptance tolerance
      actual_macros = calculate_macros(foods_with_grams)
      within_tolerance = (actual_macros[:carbs] - target_carbs).abs <= acceptance_tolerance &&
                         (actual_macros[:protein] - target_protein).abs <= acceptance_tolerance &&
                         (actual_macros[:fat] - target_fat).abs <= acceptance_tolerance

      return within_tolerance
    end

    # This should never happen since we always try at least 1 restart
    Rails.logger.error("=== No solution found after #{num_restarts} restarts (unexpected!)")
    false
  end

  # Phase 2: Adjust portions across all meals to meet daily targets
  # Returns true if adjustment succeeded, false otherwise
  def adjust_portions_for_daily_targets(composed_meals, target_carbs, target_protein, target_fat)
    # Calculate current daily totals
    current_carbs = composed_meals.values.sum { |m| m[:actual_carbs] }
    current_protein = composed_meals.values.sum { |m| m[:actual_protein] }
    current_fat = composed_meals.values.sum { |m| m[:actual_fat] }

    # Calculate errors (positive = too much, negative = too little)
    carb_error = current_carbs - target_carbs
    protein_error = current_protein - target_protein
    fat_error = current_fat - target_fat

    Rails.logger.info("=== Phase 2 errors: C:#{carb_error > 0 ? '+' : ''}#{carb_error.round(1)}g " \
                     "P:#{protein_error > 0 ? '+' : ''}#{protein_error.round(1)}g " \
                     "F:#{fat_error > 0 ? '+' : ''}#{fat_error.round(1)}g")

    # Try up to 10 micro-adjustments
    10.times do |iteration|
      # Find the macro with the worst error
      worst_macro = nil
      worst_error = 0.0

      if carb_error.abs > MACRO_TOLERANCE_GRAMS && carb_error.abs > worst_error.abs
        worst_macro = :carbs
        worst_error = carb_error
      end

      if protein_error.abs > MACRO_TOLERANCE_GRAMS && protein_error.abs > worst_error.abs
        worst_macro = :protein
        worst_error = protein_error
      end

      if fat_error.abs > MACRO_TOLERANCE_GRAMS && fat_error.abs > worst_error.abs
        worst_macro = :fat
        worst_error = fat_error
      end

      # If all macros within tolerance, success!
      break unless worst_macro

      Rails.logger.info("=== Phase 2 iteration #{iteration + 1}: Adjusting #{worst_macro} (error: #{worst_error > 0 ? '+' : ''}#{worst_error.round(1)}g)")

      # Find meals and foods that can help fix this macro
      adjustment_made = adjust_single_macro(composed_meals, worst_macro, worst_error)

      unless adjustment_made
        Rails.logger.info("=== Phase 2: No valid adjustment found for #{worst_macro}")
        return false
      end

      # Recalculate errors after adjustment
      current_carbs = composed_meals.values.sum { |m| m[:actual_carbs] }
      current_protein = composed_meals.values.sum { |m| m[:actual_protein] }
      current_fat = composed_meals.values.sum { |m| m[:actual_fat] }

      carb_error = current_carbs - target_carbs
      protein_error = current_protein - target_protein
      fat_error = current_fat - target_fat
    end

    # Check if we succeeded
    success = carb_error.abs <= MACRO_TOLERANCE_GRAMS &&
              protein_error.abs <= MACRO_TOLERANCE_GRAMS &&
              fat_error.abs <= MACRO_TOLERANCE_GRAMS

    # If failed, provide diagnostic information
    unless success
      diagnose_phase2_failure(composed_meals, target_carbs, target_protein, target_fat,
                              carb_error, protein_error, fat_error)
    end

    success
  end

  # Diagnose why Phase 2 failed and provide actionable suggestions
  def diagnose_phase2_failure(composed_meals, target_carbs, target_protein, target_fat,
                              carb_error, protein_error, fat_error)
    failing_macros = []
    failing_macros << { name: "Carbs", error: carb_error, target: target_carbs } if carb_error.abs > MACRO_TOLERANCE_GRAMS
    failing_macros << { name: "Protein", error: protein_error, target: target_protein } if protein_error.abs > MACRO_TOLERANCE_GRAMS
    failing_macros << { name: "Fat", error: fat_error, target: target_fat } if fat_error.abs > MACRO_TOLERANCE_GRAMS

    # Check for foods at min/max limits
    foods_at_limits = []
    composed_meals.each do |meal_type, meal_data|
      meal_data[:foods_with_grams].each do |food_with_grams|
        if food_with_grams.grams <= MIN_PORTION_SIZE + 1
          foods_at_limits << { food: food_with_grams.food.description, meal: meal_type, limit: "minimum", grams: food_with_grams.grams }
        elsif food_with_grams.grams >= MAX_PORTION_SIZE - 1
          foods_at_limits << { food: food_with_grams.food.description, meal: meal_type, limit: "maximum", grams: food_with_grams.grams }
        end
      end
    end

    # Build user-friendly error message
    user_message = "Cannot achieve macro targets with selected foods.\n\n"

    user_message += "Missing targets:\n"
    failing_macros.each do |macro|
      direction = macro[:error] < 0 ? "short" : "over"
      user_message += "• #{macro[:name]}: #{macro[:error].abs.round(0)}g #{direction} (need #{macro[:target].round(0)}g total)\n"
    end

    user_message += "\nSuggestions:\n"
    suggestions_added = false

    if protein_error < -MACRO_TOLERANCE_GRAMS && foods_at_limits.any? { |f| f[:limit] == "maximum" }
      user_message += "• Add more protein-rich foods to your meal structure\n"
      user_message += "• Some protein sources reached maximum portions (500g)\n"
      suggestions_added = true
    end

    if fat_error > MACRO_TOLERANCE_GRAMS && protein_error < -MACRO_TOLERANCE_GRAMS
      user_message += "• Try leaner protein sources (chicken breast, egg whites, lean fish)\n"
      user_message += "• Or adjust your macro targets - this protein:fat ratio is difficult with current foods\n"
      suggestions_added = true
    elsif fat_error > MACRO_TOLERANCE_GRAMS
      user_message += "• Reduce high-fat foods or replace with lower-fat alternatives\n"
      suggestions_added = true
    elsif fat_error < -MACRO_TOLERANCE_GRAMS
      user_message += "• Add more fat sources (oils, nuts, avocado, fatty fish)\n"
      suggestions_added = true
    end

    if carb_error.abs > MACRO_TOLERANCE_GRAMS
      direction = carb_error < 0 ? "higher-carb" : "lower-carb"
      user_message += "• Select #{direction} foods for your meals\n"
      suggestions_added = true
    end

    if protein_error < -MACRO_TOLERANCE_GRAMS && !suggestions_added
      user_message += "• Add more protein-rich foods (meat, fish, eggs, dairy)\n"
      suggestions_added = true
    elsif protein_error > MACRO_TOLERANCE_GRAMS && !suggestions_added
      user_message += "• Reduce protein portions or choose foods with less protein\n"
      suggestions_added = true
    end

    unless suggestions_added
      user_message += "• Try different food combinations or adjust macro targets\n"
    end

    @failure_message = user_message

    # Also log detailed diagnostics
    Rails.logger.error("=== Phase 2 FAILURE DIAGNOSIS ===")
    Rails.logger.error("Macros still exceeding ±#{MACRO_TOLERANCE_GRAMS}g tolerance:")
    failing_macros.each do |macro|
      direction = macro[:error] < 0 ? "SHORT" : "OVER"
      Rails.logger.error("  - #{macro[:name]}: #{macro[:error].abs.round(1)}g #{direction} (target: #{macro[:target].round(0)}g)")
    end

    if foods_at_limits.any?
      Rails.logger.error("Foods at portion limits (can't adjust further):")
      foods_at_limits.each do |item|
        Rails.logger.error("  - #{item[:food]} in #{item[:meal]}: #{item[:grams].round(0)}g (at #{item[:limit]})")
      end
    end
  end

  # Adjust portions to fix a single macro across all meals
  def adjust_single_macro(composed_meals, macro, error)
    # error > 0 means too much of this macro, need to reduce
    # error < 0 means too little, need to increase

    # Find all foods across all meals, sorted by their contribution to this macro
    food_contributions = []

    composed_meals.each do |meal_type, meal_data|
      meal_data[:foods_with_grams].each_with_index do |food_with_grams, food_idx|
        macros = NutrientLookupService.macronutrients_for(food_with_grams.food)
        macro_per_gram = case macro
        when :carbs then (macros[:carbohydrates] || 0) / 100.0
        when :protein then (macros[:protein] || 0) / 100.0
        when :fat then (macros[:fat] || 0) / 100.0
        end

        food_contributions << {
          meal_type: meal_type,
          food_idx: food_idx,
          food_with_grams: food_with_grams,
          macro_per_gram: macro_per_gram.to_f,
          current_grams: food_with_grams.grams.to_f
        }
      end
    end

    # Sort by macro contribution (descending) - we want foods that provide most of this macro
    food_contributions.sort_by! { |fc| -fc[:macro_per_gram] }

    # Try to adjust the food that contributes most to this macro
    food_contributions.each do |fc|
      next if fc[:macro_per_gram] < 0.01 # Skip foods with negligible contribution

      # Calculate how many grams we need to adjust
      # error > 0 (too much) -> reduce portions (negative adjustment)
      # error < 0 (too little) -> increase portions (positive adjustment)
      # Use 50% of the calculated adjustment to make incremental changes across iterations
      full_adjustment = -(error / fc[:macro_per_gram]).to_f
      grams_to_adjust = (full_adjustment * 0.5).to_f  # Partial adjustment

      # Further cap the adjustment to ±100g per iteration to avoid extreme changes
      if grams_to_adjust.abs > 100.0
        grams_to_adjust = grams_to_adjust > 0 ? 100.0 : -100.0
      end

      # Clamp adjustment to reasonable bounds
      new_grams = (fc[:current_grams] + grams_to_adjust).to_f
      new_grams = [ [ new_grams, MIN_PORTION_SIZE.to_f ].max, MAX_PORTION_SIZE.to_f ].min

      # Only apply if it's a meaningful change (at least 5g difference)
      if (new_grams - fc[:current_grams]).abs >= 5.0
        Rails.logger.info("=== Phase 2: Adjusting #{fc[:food_with_grams].food.description} in #{fc[:meal_type]} " \
                         "from #{fc[:current_grams].round(0)}g to #{new_grams.round(0)}g")

        # Update the food portion
        fc[:food_with_grams].grams = new_grams

        # Recalculate meal macros
        meal_data = composed_meals[fc[:meal_type]]
        recalculate_meal_macros(meal_data)

        return true
      end
    end

    false
  end

  # Recalculate a meal's actual macros after portion adjustment
  def recalculate_meal_macros(meal_data)
    total_carbs = 0.0
    total_protein = 0.0
    total_fat = 0.0

    meal_data[:foods_with_grams].each do |food_with_grams|
      macros = NutrientLookupService.macronutrients_for(food_with_grams.food)
      grams = food_with_grams.grams.to_f

      total_carbs += ((macros[:carbohydrates] || 0) / 100.0) * grams
      total_protein += ((macros[:protein] || 0) / 100.0) * grams
      total_fat += ((macros[:fat] || 0) / 100.0) * grams
    end

    meal_data[:actual_carbs] = total_carbs.to_f
    meal_data[:actual_protein] = total_protein.to_f
    meal_data[:actual_fat] = total_fat.to_f
  end

  # Calculate smart initial portions based on macro scarcity
  # Foods high in abundant macros start larger, foods high in scarce macros start smaller
  def calculate_smart_initial_portions(coefficients, target_carbs, target_protein, target_fat, restart_seed: 0)
    # Calculate max available for each macro if all foods at max portion
    max_available_carbs = coefficients.sum { |c| c[:carbs] * MAX_PORTION_SIZE }
    max_available_protein = coefficients.sum { |c| c[:protein] * MAX_PORTION_SIZE }
    max_available_fat = coefficients.sum { |c| c[:fat] * MAX_PORTION_SIZE }

    # Calculate scarcity ratios (higher = more scarce/constrained)
    # Avoid division by zero - if max_available is 0, macro is impossible so scarcity is 0
    carb_scarcity = max_available_carbs > 0 ? (target_carbs / max_available_carbs).to_f : 0.0
    protein_scarcity = max_available_protein > 0 ? (target_protein / max_available_protein).to_f : 0.0
    fat_scarcity = max_available_fat > 0 ? (target_fat / max_available_fat).to_f : 0.0

    # Normalize scarcity ratios to 0-1 range based on the most scarce macro
    max_scarcity = [ carb_scarcity, protein_scarcity, fat_scarcity ].max
    if max_scarcity > 0
      carb_scarcity = (carb_scarcity / max_scarcity).to_f
      protein_scarcity = (protein_scarcity / max_scarcity).to_f
      fat_scarcity = (fat_scarcity / max_scarcity).to_f
    end

    Rails.logger.info("=== Scarcity ratios: C:#{(carb_scarcity * 100).round(1)}% P:#{(protein_scarcity * 100).round(1)}% F:#{(fat_scarcity * 100).round(1)}%")

    # Calculate initial portions for each food based on its macro density and scarcity
    portions = coefficients.map.with_index do |coef, i|
      # Calculate how much this food contributes to each macro (weighted by scarcity)
      # Foods HIGH in SCARCE macros should start LARGER (we need more of them to meet targets)
      # Foods HIGH in ABUNDANT macros should start SMALLER (we need less of them)
      carb_contribution = coef[:carbs] * carb_scarcity
      protein_contribution = coef[:protein] * protein_scarcity
      fat_contribution = coef[:fat] * fat_scarcity

      total_contribution = carb_contribution + protein_contribution + fat_contribution

      # Base portion logic (CORRECTED):
      # - High contribution to SCARCE macros (high scarcity) -> LARGER portion (150g+)
      #   Example: Oil is 100% fat, fat is scarce on keto -> start oil at 150g
      # - Low contribution to scarce macros -> SMALLER portion (60g)
      #   Example: Lettuce is mostly carbs/water, carbs abundant on keto -> start at 60g
      # - Balanced contribution -> medium portion (100g)

      if total_contribution > 0.15  # High in scarce macros - START LARGER
        base_portion = 150.0
      elsif total_contribution < 0.05  # Low in scarce macros - START SMALLER
        base_portion = 60.0
      else  # Medium contribution
        base_portion = 100.0
      end

      base_portion.to_f
    end

    # Add randomization for restarts > 0
    if restart_seed > 0
      Rails.logger.info("=== Applying random variation for restart #{restart_seed}")
      portions = portions.map do |p|
        # Random variation between 0.3x and 2.0x (±70% range)
        variation_factor = (0.3 + rand * 1.7).to_f
        new_p = (p * variation_factor).to_f
        # Clamp to valid range
        if new_p < MIN_PORTION_SIZE
          MIN_PORTION_SIZE.to_f
        elsif new_p > MAX_PORTION_SIZE
          MAX_PORTION_SIZE.to_f
        else
          new_p
        end
      end
    end

    portions
  end

  # Single optimization attempt using gradient descent
  def optimize_portions_once(foods_with_grams, target_carbs, target_protein, target_fat,
                             convergence_tolerance:, acceptance_tolerance:, relaxed: false, last_resort: false, restart_seed: 0)
    # Extract macro coefficients per gram for each food
    coefficients = foods_with_grams.map do |item|
      macros = NutrientLookupService.macronutrients_for(item.food)
      {
        carbs: (macros[:carbohydrates] || 0) / 100.0,
        protein: (macros[:protein] || 0) / 100.0,
        fat: (macros[:fat] || 0) / 100.0
      }
    end

    # Use smart scarcity-based initialization instead of equal portions
    n = foods_with_grams.length
    portions = calculate_smart_initial_portions(coefficients, target_carbs, target_protein, target_fat, restart_seed: restart_seed)

    best_portions = portions.dup
    best_error = Float::INFINITY

    # Tolerances are passed in from compose_single_meal, already distributed from daily tolerance
    # They are already scaled by relaxed/last_resort flags in the calling methods

    # Gradient descent optimization
    no_improvement_count = 0
    final_iter = 0

    MAX_ITERATIONS.times do |iter|
      final_iter = iter

      # Calculate current macros - use simple loop instead of enumerator
      current_carbs = 0.0
      current_protein = 0.0
      current_fat = 0.0
      n.times do |i|
        current_carbs += portions[i] * coefficients[i][:carbs]
        current_protein += portions[i] * coefficients[i][:protein]
        current_fat += portions[i] * coefficients[i][:fat]
      end

      # Calculate errors
      carb_error = target_carbs - current_carbs
      protein_error = target_protein - current_protein
      fat_error = target_fat - current_fat

      # Use dynamic weighted error to prioritize macros that are furthest off proportionally
      total_error = calculate_dynamic_weighted_error(
        carb_error, protein_error, fat_error,
        target_carbs, target_protein, target_fat
      )

      # Log only every 10 iterations to test if logging is the bottleneck
      Rails.logger.info("=== Iter #{iter}: C:#{carb_error.round(1)}g P:#{protein_error.round(1)}g F:#{fat_error.round(1)}g") if iter % 10 == 0

      # Save best solution
      if total_error < best_error
        best_error = total_error
        best_portions = portions.dup
        no_improvement_count = 0

        # Early exit if all macros are within convergence tolerance (tighter goal)
        if carb_error.abs <= convergence_tolerance && protein_error.abs <= convergence_tolerance && fat_error.abs <= convergence_tolerance
          Rails.logger.info("=== Converged at iteration #{iter} - all macros within convergence tolerance (±#{convergence_tolerance.round(1)}g)")
          break
        end
      else
        no_improvement_count += 1
      end

      # Early termination if stuck (no improvement for 30 iterations)
      if no_improvement_count >= 30
        Rails.logger.info("=== Stopping at iteration #{iter} - no improvement for 30 iterations")
        break
      end

      # Calculate weights ONCE per iteration instead of per-food
      carb_prop_error = target_carbs > 0 ? (carb_error.abs / target_carbs) : 0
      protein_prop_error = target_protein > 0 ? (protein_error.abs / target_protein) : 0
      fat_prop_error = target_fat > 0 ? (fat_error.abs / target_fat) : 0
      max_prop_error = [ carb_prop_error, protein_prop_error, fat_prop_error ].max

      carb_weight = max_prop_error > 0 ? (1.0 + carb_prop_error / max_prop_error) : 1.0
      protein_weight = max_prop_error > 0 ? (1.0 + protein_prop_error / max_prop_error) : 1.0
      fat_weight = max_prop_error > 0 ? (1.0 + fat_prop_error / max_prop_error) : 1.0

      # Update portions using pre-calculated weights
      # Force all operations to use Float to avoid BigDecimal/Rational explosion
      i = 0
      while i < n
        # Extract coefficient values and force to Float
        coef_carbs = coefficients[i][:carbs].to_f
        coef_protein = coefficients[i][:protein].to_f
        coef_fat = coefficients[i][:fat].to_f

        # Calculate gradient step by step, forcing Float
        carb_component = (carb_weight * carb_error * coef_carbs).to_f
        protein_component = (protein_weight * protein_error * coef_protein).to_f
        fat_component = (fat_weight * fat_error * coef_fat).to_f

        gradient = (2.0 * (carb_component + protein_component + fat_component)).to_f

        # Update portion, forcing Float
        new_portion = (portions[i].to_f + (LEARNING_RATE * gradient)).to_f

        # Clamp to bounds
        if new_portion < MIN_PORTION_SIZE
          new_portion = MIN_PORTION_SIZE.to_f
        elsif new_portion > MAX_PORTION_SIZE
          new_portion = MAX_PORTION_SIZE.to_f
        end

        portions[i] = new_portion
        i += 1
      end
    end

    Rails.logger.info("=== Completed gradient descent loop after #{final_iter + 1} iterations (max: #{MAX_ITERATIONS})")

    # Apply best solution
    foods_with_grams.each_with_index do |item, i|
      item.grams = best_portions[i].round(1)
    end

    Rails.logger.info("=== Optimization complete after gradient descent")

    # Check if within acceptance tolerance (more lenient than convergence tolerance)
    actual_macros = calculate_macros(foods_with_grams)
    within_tolerance = (actual_macros[:carbs] - target_carbs).abs <= acceptance_tolerance &&
                       (actual_macros[:protein] - target_protein).abs <= acceptance_tolerance &&
                       (actual_macros[:fat] - target_fat).abs <= acceptance_tolerance

    # Log final result
    carb_diff = (actual_macros[:carbs] - target_carbs).round(1)
    protein_diff = (actual_macros[:protein] - target_protein).round(1)
    fat_diff = (actual_macros[:fat] - target_fat).round(1)
    Rails.logger.info("=== Final: C:#{carb_diff}g P:#{protein_diff}g F:#{fat_diff}g - #{within_tolerance ? 'SUCCESS' : 'FAILED'} " \
                     "(acceptance tolerance: ±#{acceptance_tolerance.round(1)}g, convergence was: ±#{convergence_tolerance.round(1)}g)")

    within_tolerance
  end

  # Calculate actual macros for a set of foods with portions
  def calculate_macros(foods_with_grams)
    totals = { carbs: 0, protein: 0, fat: 0 }

    foods_with_grams.each do |item|
      macros = NutrientLookupService.macronutrients_for(item.food)
      multiplier = item.grams / 100.0

      totals[:carbs] += (macros[:carbohydrates] || 0) * multiplier
      totals[:protein] += (macros[:protein] || 0) * multiplier
      totals[:fat] += (macros[:fat] || 0) * multiplier
    end

    totals
  end

  # Persist the composed meal plan to the database
  def persist_meal_plan(composed_meals, actual_carbs, actual_protein, actual_fat)
    ActiveRecord::Base.transaction do
      # Check tolerance
      within_tolerance = (actual_carbs - daily_macro_target.carbs_grams).abs <= MACRO_TOLERANCE_GRAMS &&
                        (actual_protein - daily_macro_target.protein_grams).abs <= MACRO_TOLERANCE_GRAMS &&
                        (actual_fat - daily_macro_target.fat_grams).abs <= MACRO_TOLERANCE_GRAMS

      # Create DailyMealPlan
      daily_meal_plan = user.daily_meal_plans.create!(
        name: name,
        daily_macro_target: daily_macro_target,
        daily_meal_structure: daily_meal_structure,
        target_carbs_grams: daily_macro_target.carbs_grams,
        target_protein_grams: daily_macro_target.protein_grams,
        target_fat_grams: daily_macro_target.fat_grams,
        actual_carbs_grams: actual_carbs,
        actual_protein_grams: actual_protein,
        actual_fat_grams: actual_fat,
        within_tolerance: within_tolerance
      )

      # Create Meals and FoodPortions
      composed_meals.each do |meal_type, meal_data|
        meal = daily_meal_plan.meals.create!(
          meal_type: meal_type.to_s,
          actual_carbs_grams: meal_data[:actual_carbs],
          actual_protein_grams: meal_data[:actual_protein],
          actual_fat_grams: meal_data[:actual_fat]
        )

        meal_data[:foods_with_grams].each do |item|
          meal.food_portions.create!(
            food: item.food,
            grams: item.grams
          )
        end
      end

      daily_meal_plan
    end
  end

  # Get meal labels from the daily meal structure, ordered by position
  def get_meal_labels
    daily_meal_structure.meal_structure_items.order(:position).pluck(:meal_label)
  end
end
