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

    # Distribute daily macros across meals
    meal_targets = distribute_macros_across_meals

    # Compose each meal
    composed_meals = {}
    [ :breakfast, :lunch, :dinner ].each do |meal_type|
      Rails.logger.info("=== MealPlanGenerator: Composing #{meal_type}")

      meal_result = compose_single_meal(
        meal_type: meal_type,
        target_carbs: meal_targets[meal_type][:carbs],
        target_protein: meal_targets[meal_type][:protein],
        target_fat: meal_targets[meal_type][:fat]
      )

      unless meal_result
        return Result.new(success?: false, error: "Failed to compose #{meal_type} meal after multiple attempts")
      end

      composed_meals[meal_type] = meal_result
    end

    # Calculate total actual macros
    actual_carbs = composed_meals.values.sum { |m| m[:actual_carbs] }
    actual_protein = composed_meals.values.sum { |m| m[:actual_protein] }
    actual_fat = composed_meals.values.sum { |m| m[:actual_fat] }

    # Persist to database
    daily_meal_plan = persist_meal_plan(composed_meals, actual_carbs, actual_protein, actual_fat)

    Result.new(success?: true, daily_meal_plan: daily_meal_plan)
  rescue StandardError => e
    Rails.logger.error("MealPlanGenerator failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    Result.new(success?: false, error: "An unexpected error occurred: #{e.message}")
  end

  private

  attr_reader :user, :name, :daily_macro_target, :daily_meal_structure

  # Distribute daily macros across meals using fixed percentages
  def distribute_macros_across_meals
    {
      breakfast: {
        carbs: (daily_macro_target.carbs_grams * 0.30).round,
        protein: (daily_macro_target.protein_grams * 0.25).round,
        fat: (daily_macro_target.fat_grams * 0.25).round
      },
      lunch: {
        carbs: (daily_macro_target.carbs_grams * 0.35).round,
        protein: (daily_macro_target.protein_grams * 0.35).round,
        fat: (daily_macro_target.fat_grams * 0.35).round
      },
      dinner: {
        carbs: (daily_macro_target.carbs_grams * 0.35).round,
        protein: (daily_macro_target.protein_grams * 0.40).round,
        fat: (daily_macro_target.fat_grams * 0.40).round
      }
    }
  end

  # Compose a single meal by selecting foods and optimizing portions
  def compose_single_meal(meal_type:, target_carbs:, target_protein:, target_fat:)
    # Get category IDs for this meal from the meal structure
    meal_structure_item = daily_meal_structure.meal_structure_items.find_by(meal_label: meal_type.to_s)
    unless meal_structure_item
      Rails.logger.error("No meal structure item found for #{meal_type}")
      return nil
    end

    category_ids = meal_structure_item.food_category_ids
    max_attempts = 10

    max_attempts.times do |attempt|
      Rails.logger.info("=== MealPlanGenerator: #{meal_type} - Attempt #{attempt + 1}/#{max_attempts}")

      # Randomly select one food from each category
      foods_with_grams = randomly_select_foods(category_ids)

      # Try to optimize portions
      if optimize_portions(foods_with_grams, target_carbs, target_protein, target_fat)
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
        if optimize_portions(foods_with_grams, target_carbs, target_protein, target_fat, relaxed: true)
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
    if optimize_portions(foods_with_grams, target_carbs, target_protein, target_fat, last_resort: true)
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

  # Optimize portion sizes using gradient descent
  def optimize_portions(foods_with_grams, target_carbs, target_protein, target_fat, relaxed: false, last_resort: false)
    # Extract macro coefficients per gram for each food
    coefficients = foods_with_grams.map do |item|
      macros = NutrientLookupService.macronutrients_for(item.food)
      {
        carbs: (macros[:carbohydrates] || 0) / 100.0,
        protein: (macros[:protein] || 0) / 100.0,
        fat: (macros[:fat] || 0) / 100.0
      }
    end

    # Initialize with equal portions totaling 300g
    n = foods_with_grams.length
    portions = Array.new(n, 300.0 / n)
    best_portions = portions.dup
    best_error = Float::INFINITY

    # Set tolerance based on relaxation level
    tolerance = if last_resort
      MACRO_TOLERANCE_GRAMS * 4
    elsif relaxed
      MACRO_TOLERANCE_GRAMS * 2
    else
      MACRO_TOLERANCE_GRAMS
    end

    # Gradient descent optimization
    MAX_ITERATIONS.times do |iter|
      # Calculate current macros
      current_carbs = portions.each_with_index.sum { |p, i| p * coefficients[i][:carbs] }
      current_protein = portions.each_with_index.sum { |p, i| p * coefficients[i][:protein] }
      current_fat = portions.each_with_index.sum { |p, i| p * coefficients[i][:fat] }

      # Calculate errors
      carb_error = target_carbs - current_carbs
      protein_error = target_protein - current_protein
      fat_error = target_fat - current_fat
      total_error = carb_error**2 + protein_error**2 + fat_error**2

      # Save best solution
      if total_error < best_error
        best_error = total_error
        best_portions = portions.dup

        # Early exit if within tolerance
        break if Math.sqrt(best_error) < tolerance
      end

      # Update portions using gradient
      n.times do |i|
        gradient = 2 * (
          carb_error * coefficients[i][:carbs] +
          protein_error * coefficients[i][:protein] +
          fat_error * coefficients[i][:fat]
        )

        portions[i] += LEARNING_RATE * gradient
        portions[i] = [ [ portions[i], MIN_PORTION_SIZE ].max, MAX_PORTION_SIZE ].min
      end
    end

    # Apply best solution
    foods_with_grams.each_with_index do |item, i|
      item.grams = best_portions[i].round(1)
    end

    # Check if within tolerance
    actual_macros = calculate_macros(foods_with_grams)
    (actual_macros[:carbs] - target_carbs).abs <= tolerance &&
    (actual_macros[:protein] - target_protein).abs <= tolerance &&
    (actual_macros[:fat] - target_fat).abs <= tolerance
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
end
