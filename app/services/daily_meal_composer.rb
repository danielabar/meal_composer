class DailyMealComposer
  MACRO_TOLERANCE_GRAMS = 15.0  # Increased tolerance for better success rate

  DEFAULT_MEAL_CATEGORIES = {
    breakfast: [ 1, 4, 9 ],    # Dairy and Egg Products, Fats and Oils, Fruits and Fruit Juices
    lunch: [ 5, 4, 11 ],       # Poultry Products, Fats and Oils, Vegetables and Vegetable Products
    dinner: [ 13, 4, 11 ]      # Beef Products, Fats and Oils, Vegetables and Vegetable Products
  }.freeze

  def initialize
    @daily_food_usage = Hash.new(0)  # Track food usage across all meals for variety
  end

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

    # VARIETY-FIRST APPROACH: Select diverse foods from required categories first
    required_categories.each do |macro_type, category_ids|
      category_foods = available_foods.select { |food| category_ids.include?(food.food_category_id) }
      next if category_foods.empty?

      Rails.logger.info "DEBUG: Selecting diverse #{macro_type} source from categories #{category_ids}"

      # Calculate current gap for smart selection
      gap = MacroTargets.new(
        carbs: meal_targets.carbs - current_macros.carbs,
        protein: meal_targets.protein - current_macros.protein,
        fat: meal_targets.fat - current_macros.fat
      )

      # Use smart selection that balances feasibility and variety
      selected_food = select_diverse_food(category_foods, gap)
      if selected_food
        # Start with reasonable portion, not optimized portion
        reasonable_grams = calculate_reasonable_portion(selected_food, meal_targets, current_macros)
        selected_foods << FoodPortion.new(food: selected_food, grams: reasonable_grams)
        add_food_macros_to_current(current_macros, selected_food, reasonable_grams)

        # Track usage for variety across all meals
        @daily_food_usage[selected_food.id] += 1

        Rails.logger.info "DEBUG: Selected diverse #{macro_type}: #{reasonable_grams.round(1)}g of #{selected_food.description}"
        Rails.logger.info "DEBUG: Current macros after #{macro_type}: carbs=#{current_macros.carbs.round(1)}, protein=#{current_macros.protein.round(1)}, fat=#{current_macros.fat.round(1)}"
      end
    end

    # Now adjust portions of selected diverse foods to hit macro targets
    adjust_portions_to_targets(selected_foods, meal_targets, current_macros)

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

  def select_diverse_food(available_foods, gap = nil)
    # Filter foods with complete macro data
    valid_foods = available_foods.select do |food|
      food_macros = NutrientLookupService.macronutrients_for(food)

      # Convert nil values to 0 (common for pure oils, pure proteins, etc.)
      carbs = food_macros[:carbohydrates] || 0
      protein = food_macros[:protein] || 0
      fat = food_macros[:fat] || 0

      # Skip foods with zero values for all macros (they don't contribute anything)
      next false if carbs == 0 && protein == 0 && fat == 0

      # If we have a gap, ensure the food can contribute to at least one needed macro
      if gap
        can_help_carbs = gap.carbs > 0 && carbs > 0
        can_help_protein = gap.protein > 0 && protein > 0
        can_help_fat = gap.fat > 0 && fat > 0

        can_help_carbs || can_help_protein || can_help_fat
      else
        true
      end
    end

    return nil if valid_foods.empty?

    Rails.logger.info "DEBUG: Valid foods for selection: #{valid_foods.count}"
    if gap
      Rails.logger.info "DEBUG: Gap needed: carbs=#{gap.carbs.round(1)}, protein=#{gap.protein.round(1)}, fat=#{gap.fat.round(1)}"
    end

    # NEW: Calculate both feasibility and variety scores
    scored_foods = valid_foods.map do |food|
      # VARIETY SCORE (same as before)
      usage_count = @daily_food_usage[food.id]
      variety_score = 1.0 / (usage_count + 1.0)

      # NEW: FEASIBILITY SCORE based on largest gap
      feasibility_score = calculate_feasibility_score(food, gap)

      # COMBINED SCORE: Weight both factors (prioritize feasibility for high targets)
      combined_score = (feasibility_score * 0.7) + (variety_score * 0.3)

      Rails.logger.info "DEBUG: #{food.description} - feasibility: #{feasibility_score.round(3)}, variety: #{variety_score.round(3)}, combined: #{combined_score.round(3)}"

      { food: food, score: combined_score }
    end

    # Select from top candidates using weighted random
    top_candidates = scored_foods.sort_by { |f| -f[:score] }.first([ 5, scored_foods.count ].min)

    # Weighted random selection from top candidates
    total_weight = top_candidates.sum { |f| f[:score] }
    random_value = rand * total_weight

    cumulative_weight = 0
    top_candidates.each do |candidate|
      cumulative_weight += candidate[:score]
      if random_value <= cumulative_weight
        selected_food = candidate[:food]
        Rails.logger.info "DEBUG: Selected smart food: #{selected_food.description} (usage: #{@daily_food_usage[selected_food.id]}, score: #{candidate[:score].round(3)})"
        return selected_food
      end
    end

    # Fallback to highest scoring food
    selected_food = top_candidates.first[:food]
    Rails.logger.info "DEBUG: Fallback to top scorer: #{selected_food.description}"
    selected_food
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

  def calculate_feasibility_score(food, gap)
    return 1.0 unless gap # If no gap info, all foods are equally feasible

    food_macros = NutrientLookupService.macronutrients_for(food)
    carbs = food_macros[:carbohydrates] || 0
    protein = food_macros[:protein] || 0
    fat = food_macros[:fat] || 0

    # Find the largest gap
    gaps = { carbs: gap.carbs, protein: gap.protein, fat: gap.fat }
    largest_gap_macro, largest_gap_amount = gaps.max_by { |_, amount| amount.abs }

    return 0.1 if largest_gap_amount <= 0 # No significant gaps

    # Score based on how well this food can contribute to the largest gap
    food_contribution = case largest_gap_macro
    when :carbs then carbs
    when :protein then protein
    when :fat then fat
    end

    # Score higher if food can make a meaningful dent in the gap
    # but not so much that it overshoots wildly
    if food_contribution == 0
      0.1 # Can't help at all
    elsif food_contribution > largest_gap_amount * 3
      0.3 # Too much - would overshoot badly
    elsif food_contribution > largest_gap_amount * 0.3
      1.0 # Good match - can make meaningful progress
    else
      0.6 # Can help but only a little
    end
  end

  def calculate_reasonable_portion(food, meal_targets, current_macros)
    # Start with a moderate base portion - not trying to optimize yet
    base_portion = 60.0  # grams

    # Adjust slightly based on food type, but keep it reasonable
    food_macros = NutrientLookupService.macronutrients_for(food)

    # If it's a very macro-dense food (like oil), use smaller portion
    if (food_macros[:fat] || 0) > 80  # Very high fat foods like oils
      base_portion = 25.0
    elsif (food_macros[:protein] || 0) > 25  # High protein foods
      base_portion = 80.0
    elsif (food_macros[:carbohydrates] || 0) > 20  # High carb foods
      base_portion = 80.0
    end

    Rails.logger.info "DEBUG: Reasonable portion for #{food.description}: #{base_portion}g"
    base_portion.clamp(20.0, 120.0)
  end

  def calculate_optimal_grams(food, targets, current_macros)
    # Skip foods that don't have at least one macro we need
    # TODO: Implement optimal gram calculation logic
    60.0  # Return default portion for now
  end

  def adjust_portions_to_targets(selected_foods, meal_targets, current_macros)
    max_iterations = 10
    iteration = 0

    Rails.logger.info "DEBUG: Starting portion adjustment. Current: #{current_macros}, Target: #{meal_targets}"

    while !macros_within_tolerance?(current_macros, meal_targets) && iteration < max_iterations
      # Find which macro is furthest from target
      gaps = {
        carbs: meal_targets.carbs - current_macros.carbs,
        protein: meal_targets.protein - current_macros.protein,
        fat: meal_targets.fat - current_macros.fat
      }

      largest_gap = gaps.max_by { |_, gap| gap.abs }
      macro_needed = largest_gap[0]
      gap_amount = largest_gap[1]

      Rails.logger.info "DEBUG: Iteration #{iteration}: Largest gap is #{macro_needed}: #{gap_amount.round(1)}g"

      # Find the food that can best help with this macro
      best_food_portion = selected_foods.max_by do |portion|
        food_macros = NutrientLookupService.macronutrients_for(portion.food)
        case macro_needed
        when :carbs then food_macros[:carbohydrates] || 0
        when :protein then food_macros[:protein] || 0
        when :fat then food_macros[:fat] || 0
        end
      end

      if best_food_portion && gap_amount.abs > 1.0
        # Calculate how much to adjust this food's portion
        food_macros = NutrientLookupService.macronutrients_for(best_food_portion.food)
        macro_per_gram = case macro_needed
        when :carbs then (food_macros[:carbohydrates] || 0) / 100.0
        when :protein then (food_macros[:protein] || 0) / 100.0
        when :fat then (food_macros[:fat] || 0) / 100.0
        end

        if macro_per_gram > 0
          needed_grams = gap_amount / macro_per_gram
          adjustment = [ needed_grams, gap_amount > 0 ? 15.0 : -15.0 ].min_by(&:abs)

          old_grams = best_food_portion.grams
          new_grams = (old_grams + adjustment).clamp(15.0, 150.0)

          Rails.logger.info "DEBUG: Adjusting #{best_food_portion.food.description} from #{old_grams.round(1)}g to #{new_grams.round(1)}g"

          # Update the portion and recalculate current macros
          best_food_portion.grams = new_grams
          recalculate_current_macros(selected_foods, current_macros)
        end
      end

      iteration += 1
    end

    Rails.logger.info "DEBUG: Portion adjustment complete after #{iteration} iterations"
  end

  def recalculate_current_macros(selected_foods, current_macros)
    current_macros.carbs = 0
    current_macros.protein = 0
    current_macros.fat = 0

    selected_foods.each do |portion|
      add_food_macros_to_current(current_macros, portion.food, portion.grams)
    end
  end

  def macros_within_tolerance?(current, targets)
    (current.carbs - targets.carbs).abs <= MACRO_TOLERANCE_GRAMS &&
    (current.protein - targets.protein).abs <= MACRO_TOLERANCE_GRAMS &&
    (current.fat - targets.fat).abs <= MACRO_TOLERANCE_GRAMS
  end

  def add_food_macros_to_current(current_macros, food, grams)
    food_macros = NutrientLookupService.macronutrients_for(food)
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
    macros = NutrientLookupService.macronutrients_for(food)

    # Convert nil values to 0 (consistent with select_diverse_food logic)
    carbs = macros[:carbohydrates] || 0
    protein = macros[:protein] || 0
    fat = macros[:fat] || 0

    # Skip foods with zero values for all macros (they don't contribute anything)
    has_some_nutrition = !(carbs == 0 && protein == 0 && fat == 0)

    unless has_some_nutrition
      Rails.logger.info "DEBUG: Excluding food '#{food.description}': carbs=#{carbs}, protein=#{protein}, fat=#{fat} (no nutritional contribution)"
    end

    has_some_nutrition
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
