class DailyMealComposer
  MACRO_TOLERANCE_GRAMS = 15.0  # Increased tolerance for better success rate

  DEFAULT_MEAL_CATEGORIES = {
    breakfast: [ 1, 4, 9 ],    # Dairy and Egg Products, Fats and Oils, Fruits and Fruit Juices
    lunch: [ 5, 4, 11 ],       # Poultry Products, Fats and Oils, Vegetables and Vegetable Products
    dinner: [ 13, 4, 11 ]      # Beef Products, Fats and Oils, Vegetables and Vegetable Products
  }.freeze

  # Ensure each meal has at least one from each required category type
  REQUIRED_CATEGORIES_PER_MEAL = {
    breakfast: { dairy: [ 1 ], fat: [ 4 ], fruit: [ 9 ] },     # Dairy and Egg Products, Fats and Oils, Fruits and Fruit Juices
    lunch: { poultry: [ 5 ], fat: [ 4 ], vegetable: [ 11 ] },  # Poultry Products, Fats and Oils, Vegetables and Vegetable Products
    dinner: { beef: [ 13 ], fat: [ 4 ], vegetable: [ 11 ] }    # Beef Products, Fats and Oils, Vegetables and Vegetable Products
  }.freeze

  def compose_daily_meals(macro_targets:, meal_preferences: nil)
    preferences = meal_preferences || build_default_preferences

    # Distribute macros evenly across 3 meals
    meal_targets = distribute_macros_across_meals(macro_targets)

    composed_meals = {}
    remaining_targets = macro_targets.dup

    [ :breakfast, :lunch, :dinner ].each do |meal_type|
      meal_result = compose_single_meal(
        meal_targets[meal_type],
        preferences.categories_for_meal(meal_type),
        remaining_targets
      )

      return Result.new(composed: false, error: meal_result.error) unless meal_result.composed?

      composed_meals[meal_type] = meal_result.meal
      subtract_macros_from_remaining(remaining_targets, meal_result.meal)
    end

    Result.new(
      composed: true,
      daily_plan: DailyMealPlan.new(
        breakfast: composed_meals[:breakfast],
        lunch: composed_meals[:lunch],
        dinner: composed_meals[:dinner],
        target_macros: macro_targets,
        actual_macros: calculate_total_macros(composed_meals)
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
    all_foods = Food.joins(:food_category)
                   .where(food_category_id: allowed_categories)
                   .includes(:food_nutrients, :nutrients)

    available_foods = all_foods.select { |food| food_has_complete_macro_data?(food) }

    Rails.logger.info "DEBUG: Total foods in categories: #{all_foods.count}"
    Rails.logger.info "DEBUG: Available foods with complete macro data: #{available_foods.count}"
    Rails.logger.info "DEBUG: Meal targets: carbs=#{meal_targets.carbs}, protein=#{meal_targets.protein}, fat=#{meal_targets.fat}"
    Rails.logger.info "DEBUG: Allowed categories: #{allowed_categories}"

    # Enhanced approach: ensure variety by selecting from required categories first
    selected_foods = []
    current_macros = MacroTargets.new(carbs: 0, protein: 0, fat: 0)

    # Get meal type from allowed categories to determine required categories
    meal_type = determine_meal_type(allowed_categories)
    required_categories = REQUIRED_CATEGORIES_PER_MEAL[meal_type]

    Rails.logger.info "DEBUG: Meal type: #{meal_type}, Required categories: #{required_categories}"

    # First, select one food from each required category type
    required_categories.each do |macro_type, category_ids|
      category_foods = available_foods.select { |food| category_ids.include?(food.food_category_id) }
      next if category_foods.empty?

      Rails.logger.info "DEBUG: Selecting #{macro_type} source from categories #{category_ids}"

      best_food = find_best_food_for_gap(category_foods, meal_targets, current_macros)
      if best_food
        optimal_grams = calculate_optimal_grams(best_food, meal_targets, current_macros)
        selected_foods << FoodPortion.new(food: best_food, grams: optimal_grams)
        add_food_macros_to_current(current_macros, best_food, optimal_grams)

        Rails.logger.info "DEBUG: Selected #{macro_type}: #{optimal_grams.round(1)}g of #{best_food.description}"
        Rails.logger.info "DEBUG: Current macros after #{macro_type}: carbs=#{current_macros.carbs.round(1)}, protein=#{current_macros.protein.round(1)}, fat=#{current_macros.fat.round(1)}"
      end
    end

    # Now fill any remaining gaps with additional foods if needed
    max_iterations = 15  # More iterations for better solutions
    iteration = 0

    while !macros_within_tolerance?(current_macros, meal_targets) && iteration < max_iterations
      Rails.logger.info "DEBUG: Iteration #{iteration}, current_macros: carbs=#{current_macros.carbs}, protein=#{current_macros.protein}, fat=#{current_macros.fat}"

      best_food = find_best_food_for_gap(
        available_foods.to_a - selected_foods.map(&:food),  # Convert to array
        meal_targets,
        current_macros
      )

      Rails.logger.info "DEBUG: Best food found: #{best_food&.description}"
      break unless best_food

      # Track macros before adding food to detect if we're making progress
      previous_total = current_macros.carbs + current_macros.protein + current_macros.fat

      optimal_grams = calculate_optimal_grams(best_food, meal_targets, current_macros)
      Rails.logger.info "DEBUG: Optimal grams: #{optimal_grams}"

      selected_foods << FoodPortion.new(
        food: best_food,
        grams: optimal_grams
      )

      add_food_macros_to_current(current_macros, best_food, optimal_grams)
      Rails.logger.info "DEBUG: After adding food, current_macros: carbs=#{current_macros.carbs}, protein=#{current_macros.protein}, fat=#{current_macros.fat}"

      # Check if we made progress - if not, break to avoid infinite loop
      new_total = current_macros.carbs + current_macros.protein + current_macros.fat
      if (new_total - previous_total).abs < 0.01  # No meaningful progress
        Rails.logger.info "DEBUG: No progress made, breaking out of loop"
        break
      end

      iteration += 1
    end

    Rails.logger.info "DEBUG: Final selected_foods count: #{selected_foods.count}"

    if macros_within_tolerance?(current_macros, meal_targets)
      SingleMealResult.new(
        composed: true,
        meal: Meal.new(food_portions: selected_foods, macros: current_macros)
      )
    else
      SingleMealResult.new(
        composed: false,
        error: "Could not find food combination within tolerance for meal"
      )
    end
  end

  def find_best_food_for_gap(available_foods, targets, current_macros)
    gap = MacroTargets.new(
      carbs: targets.carbs - current_macros.carbs,
      protein: targets.protein - current_macros.protein,
      fat: targets.fat - current_macros.fat
    )

    Rails.logger.info "DEBUG: Gap needed: carbs=#{gap.carbs}, protein=#{gap.protein}, fat=#{gap.fat}"

    best_food = nil
    best_score = Float::INFINITY

    available_foods.each do |food|
      food_macros = food.macronutrients
      Rails.logger.info "DEBUG: Checking food '#{food.description}': carbs=#{food_macros[:carbohydrates]}, protein=#{food_macros[:protein]}, fat=#{food_macros[:fat]}"

      # Skip foods with ANY missing critical macro data
      next if food_macros[:carbohydrates].nil? || food_macros[:protein].nil? || food_macros[:fat].nil?

      # Also skip foods with zero values for all macros (they don't contribute anything)
      next if food_macros[:carbohydrates] == 0 && food_macros[:protein] == 0 && food_macros[:fat] == 0

      # Score based on how well this food matches our gap ratios
      score = calculate_food_match_score(food_macros, gap)
      Rails.logger.info "DEBUG: Food score: #{score}"

      if score < best_score
        best_score = score
        best_food = food
        Rails.logger.info "DEBUG: New best food: #{food.description} with score #{score}"
      end
    end

    Rails.logger.info "DEBUG: Final best food: #{best_food&.description} with score #{best_score}"
    best_food
  end

  def calculate_food_match_score(food_macros, gap)
    # Handle missing macro values by treating them as 0
    food_carbs = food_macros[:carbohydrates] || 0
    food_protein = food_macros[:protein] || 0
    food_fat = food_macros[:fat] || 0

    # If we have negative gaps (already exceeded), heavily penalize foods that add more
    if gap.carbs < 0 && food_carbs > 0
      return 1000.0  # Very bad score
    end
    if gap.protein < 0 && food_protein > 0
      return 1000.0  # Very bad score
    end
    if gap.fat < 0 && food_fat > 0
      return 1000.0  # Very bad score
    end

    # For positive gaps, score based on how well the food matches what we need
    score = 0.0

    if gap.carbs > 0
      if food_carbs > 0
        # Good if food provides some carbs but doesn't overshoot
        if food_carbs <= gap.carbs * 1.5  # Allow some overage but not too much
          score += (gap.carbs - food_carbs).abs * 0.5  # Bonus for good match
        else
          score += food_carbs * 2  # Penalty for overshooting
        end
      else
        score += gap.carbs * 0.1  # Small penalty for not providing needed carbs
      end
    end

    if gap.protein > 0
      if food_protein > 0
        if food_protein <= gap.protein * 1.5
          score += (gap.protein - food_protein).abs * 0.5
        else
          score += food_protein * 2
        end
      else
        score += gap.protein * 0.1
      end
    end

    if gap.fat > 0
      if food_fat > 0
        if food_fat <= gap.fat * 1.5
          score += (gap.fat - food_fat).abs * 0.5
        else
          score += food_fat * 2
        end
      else
        score += gap.fat * 0.1
      end
    end

    score
  end

  def calculate_optimal_grams(food, targets, current_macros)
    food_macros = food.macronutrients

    # Calculate remaining gaps (only positive gaps matter)
    carb_gap = [ targets.carbs - current_macros.carbs, 0 ].max
    protein_gap = [ targets.protein - current_macros.protein, 0 ].max
    fat_gap = [ targets.fat - current_macros.fat, 0 ].max

    # If no gaps remain, use small portion
    return 25.0 if carb_gap == 0 && protein_gap == 0 && fat_gap == 0

    # Calculate portion sizes that would fill each gap without overshooting
    portion_options = []

    if (food_macros[:carbohydrates] || 0) > 0 && carb_gap > 0
      # Use 90% of gap to be more aggressive in filling targets
      max_grams_for_carbs = (carb_gap * 0.9 / (food_macros[:carbohydrates] || 1)) * 100
      portion_options << max_grams_for_carbs
    end

    if (food_macros[:protein] || 0) > 0 && protein_gap > 0
      max_grams_for_protein = (protein_gap * 0.9 / (food_macros[:protein] || 1)) * 100
      portion_options << max_grams_for_protein
    end

    if (food_macros[:fat] || 0) > 0 && fat_gap > 0
      max_grams_for_fat = (fat_gap * 0.9 / (food_macros[:fat] || 1)) * 100
      portion_options << max_grams_for_fat
    end

    # Use the smallest calculated portion to avoid overshooting any macro
    if portion_options.any?
      optimal_grams = portion_options.min
    else
      optimal_grams = 30.0
    end

    optimal_grams.clamp(15.0, 80.0)  # Conservative portions to prevent overshooting
  end

  def macros_within_tolerance?(current, targets)
    (current.carbs - targets.carbs).abs <= MACRO_TOLERANCE_GRAMS &&
    (current.protein - targets.protein).abs <= MACRO_TOLERANCE_GRAMS &&
    (current.fat - targets.fat).abs <= MACRO_TOLERANCE_GRAMS
  end

  def add_food_macros_to_current(current_macros, food, grams)
    food_macros = food.macronutrients
    multiplier = grams / 100.0

    current_macros.carbs += (food_macros[:carbohydrates] || 0) * multiplier
    current_macros.protein += (food_macros[:protein] || 0) * multiplier
    current_macros.fat += (food_macros[:fat] || 0) * multiplier
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

  def food_has_complete_macro_data?(food)
    macros = food.macronutrients

    # All three macros must be present (not nil) - even if 0
    carbs_present = !macros[:carbohydrates].nil?
    protein_present = !macros[:protein].nil?
    fat_present = !macros[:fat].nil?

    has_complete_data = carbs_present && protein_present && fat_present

    unless has_complete_data
      Rails.logger.info "DEBUG: Excluding food '#{food.description}': carbs=#{macros[:carbohydrates]}, protein=#{macros[:protein]}, fat=#{macros[:fat]} (incomplete data)"
    end

    has_complete_data
  end

  def determine_meal_type(allowed_categories)
    # Breakfast has dairy (1) and fruits (9)
    if allowed_categories.include?(1) && allowed_categories.include?(9)
      :breakfast
    # Lunch has poultry (5)
    elsif allowed_categories.include?(5)
      :lunch
    # Dinner has beef (13)
    elsif allowed_categories.include?(13)
      :dinner
    else
      :breakfast  # Default fallback
    end
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
