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
  MAX_ITERATIONS = 200
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
  end

  def generate
    Rails.logger.info("=== MealPlanGenerator: Starting generation for user #{@user.id}")
    Rails.logger.info("=== MealPlanGenerator: Targets: #{@daily_macro_target.carbs_grams}g C, #{@daily_macro_target.protein_grams}g P, #{@daily_macro_target.fat_grams}g F")

    composition_result = compose_meals

    if composition_result.nil?
      return Result.new(success?: false, error: "Failed to compose meals after multiple attempts")
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

    Rails.logger.error("=== MealPlanGenerator: #{meal_type} - Failed after all attempts")
    nil
  end

  # Compose meal using food-based selection (new logic)
  def compose_meal_by_foods(meal_type, meal_structure_item, target_carbs, target_protein, target_fat,
                            convergence_tolerance, acceptance_tolerance)
    food_ids = meal_structure_item.food_ids
    max_attempts = 10

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

    Rails.logger.error("=== MealPlanGenerator: #{meal_type} - Food-based failed after all attempts")
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

  # Optimize portion sizes using gradient descent
  def optimize_portions(foods_with_grams, target_carbs, target_protein, target_fat,
                       convergence_tolerance:, acceptance_tolerance:, relaxed: false, last_resort: false)
    # Extract macro coefficients per gram for each food
    coefficients = foods_with_grams.map do |item|
      macros = NutrientLookupService.macronutrients_for(item.food)
      {
        carbs: (macros[:carbohydrates] || 0) / 100.0,
        protein: (macros[:protein] || 0) / 100.0,
        fat: (macros[:fat] || 0) / 100.0
      }
    end

    Rails.logger.info("=== coefficients class: #{coefficients.class}, size: #{coefficients.size}")
    Rails.logger.info("=== coefficients[0] class: #{coefficients[0].class}")

    # Initialize with equal portions totaling 300g
    n = foods_with_grams.length
    initial_portion = 300.0 / n
    portions = Array.new(n) { initial_portion.to_f }  # Force to Float to avoid BigDecimal
    best_portions = portions.dup
    best_error = Float::INFINITY

    Rails.logger.info("=== initial_portion class: #{initial_portion.class}, value: #{initial_portion}")
    Rails.logger.info("=== portions[0] class: #{portions[0].class}, value: #{portions[0]}")

    # Tolerances are passed in from compose_single_meal, already distributed from daily tolerance
    # They are already scaled by relaxed/last_resort flags in the calling methods

    # Gradient descent optimization
    no_improvement_count = 0
    final_iter = 0

    MAX_ITERATIONS.times do |iter|
      final_iter = iter

      if iter == 10
        puts "\n=== DEBUG: Checking coefficients[0] at iter 10"
        puts "coefficients[0][:carbs] = #{coefficients[0][:carbs].inspect}"
        puts "portions[0] = #{portions[0].inspect}"

        test_start = Time.now
        test_result = portions[0] * coefficients[0][:carbs]
        test_time = ((Time.now - test_start) * 1000000).round(1)  # microseconds
        puts "Single multiplication took #{test_time} microseconds"
        puts "Result: #{test_result}"
      end

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

      # TEMPORARY: Use simple squared error to debug performance issue
      # total_error = calculate_dynamic_weighted_error(
      #   carb_error, protein_error, fat_error,
      #   target_carbs, target_protein, target_fat
      # )
      total_error = carb_error**2 + protein_error**2 + fat_error**2

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
