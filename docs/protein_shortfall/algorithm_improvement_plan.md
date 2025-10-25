# Algorithm Improvement Plan: Addressing Protein Shortfall

## Problem Overview

The algorithm in `app/services/meal_plan_generator.rb` regularly comes in under on protein targets. For example, meal plan #13 (http://localhost:3000/meal_plans/13) achieved only 45g protein against a 60g target (-15.4g difference), while hitting carbs and fat targets.

The manual solution analysis at `docs/manual-solution-2meal.md` proves that the same foods CAN achieve the targets with proper portion sizes (130g+ for protein sources vs algorithm's ~77g). This is an optimization problem, not a feasibility problem.

## Analysis of Algorithm Issues

I've identified **12 critical problems** in `app/services/meal_plan_generator.rb`:

### Root Causes of Protein Shortfall

**1. Poor Initialization Strategy (lines 344-346)**
- Equal portions at ~100g per food (300g / n foods)
- Doesn't consider macro density of different foods
- Salmon/chicken at 25% protein density need much larger portions than lettuce at 0.9%

**2. Uniform Learning Rate (line 14, 389)**
- Fixed `LEARNING_RATE = 0.5` applies same adjustment to all foods
- High-protein foods need larger adjustments than low-carb vegetables
- Causes premature convergence before protein targets are met

**3. Isotropic Error Function (lines 367-370)**
- Treats all macro errors equally: `total_error = carb_error² + protein_error² + fat_error²`
- A 15g protein shortage has same weight as 15g carb shortage
- For keto users, protein is harder to hit and more important

**4. No Exploration Mechanism**
- Only 10 random restarts for category-based mode (line 145)
- For food-based mode, no randomization at all - uses same foods every attempt (line 211)
- Gradient descent always starts from same initialization each time

**5. Inadequate Convergence Detection (lines 376-379)**
- Only checks if total error improves, not rate of improvement
- Continues iterating even when stuck in local minimum
- Wastes iterations on plateaued solutions

**6. Premature Relaxation (lines 169-180)**
- Relaxes constraints after just 5 attempts (max_attempts/2)
- Should try harder with better initialization first
- Relaxation encourages settling for suboptimal solutions

### Additional Issues Not Yet Mentioned

**7. No Food-Specific Portion Scaling**
- All foods start at equal portions regardless of macro density
- Should initialize protein sources (>20% protein) at larger portions
- Should initialize oils (100% fat) at smaller portions initially

**8. No Macro Priority in Gradient**
- Gradient treats all macro errors equally (lines 383-386)
- Should amplify protein gradient when protein is most deficient
- Current gradient: `2 * (carb_error * c + protein_error * p + fat_error * f)`
- Better: weighted gradient with priority multipliers

**9. Insufficient Attempts**
- Only 10 attempts per meal (line 145)
- With 6 food categories, that's only 10 random food combinations tried
- Should try at least 20-30 combinations before giving up

**10. No Solution Space Analysis**
- Doesn't check if selected foods CAN satisfy targets before optimization
- Example: if total available protein from all foods at max portions < target, will fail
- Should validate feasibility first

**11. Learning Rate Not Adaptive**
- Fixed 0.5 throughout all iterations
- Should start larger (0.8-1.0) and decay over time
- Should increase temporarily when stuck in local minimum

**12. No Memory of Best Combinations**
- Each of 10 attempts is independent
- Doesn't learn which food combinations get closer to targets
- Should track which foods frequently appear in better solutions

## Comprehensive Improvement Plan

### Priority 1: Critical Fixes (Highest Impact)

**1.1 Smart Initialization Based on Macro Targets**

Instead of equal portions, initialize based on macro density and targets:

```ruby
# Instead of: portions = Array.new(n, 300.0 / n)
# Use macro-density-weighted initialization:
def initialize_portions_smart(foods_with_grams, coefficients, target_protein, target_carbs, target_fat)
  portions = []
  total_target = target_protein + target_carbs + target_fat

  foods_with_grams.each_with_index do |item, i|
    protein_density = coefficients[i][:protein]
    fat_density = coefficients[i][:fat]

    # If protein is primary need and this food is high-protein, start larger
    if target_protein > 50 && protein_density > 0.15  # >15% protein
      portions[i] = 150.0  # Start at 150g for protein sources
    elsif fat_density > 0.8  # Pure fats like oils
      portions[i] = 50.0   # Start smaller for pure fats
    else
      portions[i] = 100.0  # Standard for vegetables
    end
  end

  portions
end
```

**Why this helps:** Manual solution shows salmon/chicken need 130g+ portions, but algorithm starts at ~100g and converges down to 75-80g. Starting at 150g gives optimizer a better starting point in the solution space.

**1.2 Weighted Error Function Prioritizing Protein**

Replace isotropic error with weighted error:

```ruby
# Instead of: total_error = carb_error² + protein_error² + fat_error²
# Use:
def calculate_weighted_error(carb_error, protein_error, fat_error, target_protein)
  protein_weight = target_protein > 50 ? 2.0 : 1.5  # Higher weight for high protein targets
  carb_weight = 1.0
  fat_weight = 1.0

  (carb_weight * carb_error**2) +
  (protein_weight * protein_error**2) +
  (fat_weight * fat_error**2)
end

# Update gradient calculation accordingly:
def calculate_weighted_gradient(i, carb_error, protein_error, fat_error, coefficients, target_protein)
  protein_weight = target_protein > 50 ? 2.0 : 1.5
  carb_weight = 1.0
  fat_weight = 1.0

  2 * (
    carb_weight * carb_error * coefficients[i][:carbs] +
    protein_weight * protein_error * coefficients[i][:protein] +
    fat_weight * fat_error * coefficients[i][:fat]
  )
end
```

**Why this helps:** Protein is harder to achieve than carbs/fat with typical keto foods. Weighting it higher makes the optimizer prioritize reducing protein error over other macros.

**1.3 Multiple Random Restarts (5-10 restarts)**

Try optimization from multiple starting points:

```ruby
def optimize_with_multiple_restarts(foods_with_grams, target_carbs, target_protein, target_fat, num_restarts: 5)
  best_solution = nil
  best_error = Float::INFINITY

  num_restarts.times do |restart|
    Rails.logger.info("=== Optimization restart #{restart + 1}/#{num_restarts}")

    # Use different initialization each time
    # Randomize initial portions slightly around smart initialization
    test_foods = foods_with_grams.map { |f| FoodWithGrams.new(food: f.food, grams: 0) }

    if optimize_portions_once(test_foods, target_carbs, target_protein, target_fat, restart_seed: restart)
      current_error = calculate_total_error(test_foods, target_carbs, target_protein, target_fat)

      if current_error < best_error
        best_solution = test_foods
        best_error = current_error

        # Copy portions back to original foods_with_grams
        foods_with_grams.each_with_index do |item, i|
          item.grams = test_foods[i].grams
        end
      end
    end
  end

  best_error < Float::INFINITY
end

def optimize_portions_once(foods_with_grams, target_carbs, target_protein, target_fat, restart_seed: 0)
  # Initialize with variation based on restart_seed
  coefficients = extract_coefficients(foods_with_grams)
  portions = initialize_portions_smart(foods_with_grams, coefficients, target_protein, target_carbs, target_fat)

  # Add randomization based on restart
  if restart_seed > 0
    portions = portions.map do |p|
      variation = p * (0.8 + rand * 0.4)  # ±20% variation
      [[variation, MIN_PORTION_SIZE].max, MAX_PORTION_SIZE].min
    end
  end

  # Run gradient descent...
  # (rest of current optimize_portions logic)
end
```

**Why this helps:** Manual solution exists at salmon=105g, chicken=130g. Algorithm gets stuck at ~75g. Multiple restarts explore different regions of solution space, increasing chance of finding the better solution.

### Priority 2: Optimization Improvements

**2.1 Adaptive Learning Rate with Momentum**

Replace fixed learning rate with adaptive version:

```ruby
def optimize_portions_adaptive(foods_with_grams, target_carbs, target_protein, target_fat, relaxed: false, last_resort: false)
  coefficients = extract_coefficients(foods_with_grams)
  n = foods_with_grams.length

  # Initialize portions
  portions = initialize_portions_smart(foods_with_grams, coefficients, target_protein, target_carbs, target_fat)
  best_portions = portions.dup
  best_error = Float::INFINITY

  # Momentum variables
  velocity = Array.new(n, 0.0)
  momentum = 0.9
  base_learning_rate = 1.0  # Start larger than current 0.5

  # Set tolerance
  tolerance = if last_resort
    MACRO_TOLERANCE_GRAMS * 4
  elsif relaxed
    MACRO_TOLERANCE_GRAMS * 2
  else
    MACRO_TOLERANCE_GRAMS
  end

  MAX_ITERATIONS.times do |iter|
    # Calculate current macros and errors
    current_carbs = portions.each_with_index.sum { |p, i| p * coefficients[i][:carbs] }
    current_protein = portions.each_with_index.sum { |p, i| p * coefficients[i][:protein] }
    current_fat = portions.each_with_index.sum { |p, i| p * coefficients[i][:fat] }

    carb_error = target_carbs - current_carbs
    protein_error = target_protein - current_protein
    fat_error = target_fat - current_fat

    total_error = calculate_weighted_error(carb_error, protein_error, fat_error, target_protein)

    # Save best solution
    if total_error < best_error
      best_error = total_error
      best_portions = portions.dup

      # Early exit if within tolerance
      break if Math.sqrt(best_error) < tolerance
    end

    # Adaptive learning rate: decay over time
    current_lr = base_learning_rate * (0.95 ** (iter / 20.0))

    # Update portions using gradient with momentum
    n.times do |i|
      gradient = calculate_weighted_gradient(i, carb_error, protein_error, fat_error, coefficients, target_protein)

      # Apply momentum
      velocity[i] = momentum * velocity[i] + current_lr * gradient
      portions[i] += velocity[i]

      # Clamp to bounds
      portions[i] = [[portions[i], MIN_PORTION_SIZE].max, MAX_PORTION_SIZE].min
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
```

**Why this helps:**
- Higher initial learning rate (1.0 vs 0.5) allows larger jumps to explore solution space
- Decay prevents overshooting as we approach solution
- Momentum helps escape shallow local minima by maintaining direction

**2.2 Convergence Detection with Plateau Threshold**

Stop iterating when improvement plateaus:

```ruby
def optimize_portions_with_convergence(foods_with_grams, target_carbs, target_protein, target_fat, relaxed: false, last_resort: false)
  # ... initialization code ...

  improvement_history = []
  plateau_window = 20
  plateau_threshold = 0.01

  MAX_ITERATIONS.times do |iter|
    # ... optimization step ...

    improvement_history << best_error

    # Check for convergence after enough iterations
    if improvement_history.length >= plateau_window
      recent_improvements = improvement_history[-plateau_window..-1]
      improvement_rate = (recent_improvements.first - recent_improvements.last).abs

      if improvement_rate < plateau_threshold
        Rails.logger.info("=== Converged at iteration #{iter} - plateau detected (improvement: #{improvement_rate.round(4)})")
        break
      end
    end
  end

  # ... rest of function ...
end
```

**Why this helps:** Stops wasting iterations when stuck. Can redirect effort to trying new food combinations instead.

**2.3 Simulated Annealing for Exploration**

Add occasional random perturbations to escape local minima:

```ruby
def optimize_portions_with_annealing(foods_with_grams, target_carbs, target_protein, target_fat, relaxed: false, last_resort: false)
  # ... initialization code ...

  MAX_ITERATIONS.times do |iter|
    # ... normal gradient descent step ...

    # Periodically apply simulated annealing perturbation
    if iter % 30 == 0 && iter < MAX_ITERATIONS * 0.8
      temperature = 20.0 * (1.0 - iter.to_f / MAX_ITERATIONS)  # Decay temperature

      # Randomly perturb portions to escape local minima
      portions = portions.map do |p|
        perturbation = rand(-temperature..temperature)
        new_p = p + perturbation
        [[new_p, MIN_PORTION_SIZE].max, MAX_PORTION_SIZE].min
      end

      Rails.logger.debug("=== Applied annealing perturbation at iter #{iter} (temp: #{temperature.round(1)})")
    end
  end

  # ... rest of function ...
end
```

**Why this helps:** Occasional random jumps can push optimizer out of local minima into regions with better solutions (like the 130g protein region).

### Priority 3: Food Selection Improvements

**3.1 Feasibility Pre-Check**

Validate if selected foods can possibly hit targets:

```ruby
def check_feasibility(foods_with_grams, coefficients, target_carbs, target_protein, target_fat)
  # Calculate max possible macros with all foods at MAX_PORTION_SIZE
  max_protein = coefficients.sum { |c| c[:protein] * MAX_PORTION_SIZE }
  max_carbs = coefficients.sum { |c| c[:carbs] * MAX_PORTION_SIZE }
  max_fat = coefficients.sum { |c| c[:fat] * MAX_PORTION_SIZE }

  # Calculate min possible (at MIN_PORTION_SIZE)
  min_protein = coefficients.sum { |c| c[:protein] * MIN_PORTION_SIZE }
  min_carbs = coefficients.sum { |c| c[:carbs] * MIN_PORTION_SIZE }
  min_fat = coefficients.sum { |c| c[:fat] * MIN_PORTION_SIZE }

  # Check if targets are within feasible range (with 10% buffer for tolerance)
  feasible = true

  if target_protein > max_protein * 0.9
    Rails.logger.warn("=== Protein target #{target_protein.round}g may be infeasible (max: #{max_protein.round}g)")
    feasible = false
  end

  if target_carbs > max_carbs * 0.9
    Rails.logger.warn("=== Carbs target #{target_carbs.round}g may be infeasible (max: #{max_carbs.round}g)")
    feasible = false
  end

  if target_fat > max_fat * 0.9
    Rails.logger.warn("=== Fat target #{target_fat.round}g may be infeasible (max: #{max_fat.round}g)")
    feasible = false
  end

  # Check if minimums exceed targets (too much of a macro)
  if min_carbs > target_carbs * 1.5
    Rails.logger.warn("=== Minimum carbs #{min_carbs.round}g exceeds target #{target_carbs.round}g")
    feasible = false
  end

  feasible
end

# Use in compose_meal_by_categories:
def compose_meal_by_categories(meal_type, meal_structure_item, target_carbs, target_protein, target_fat)
  category_ids = meal_structure_item.food_category_ids
  max_attempts = 30  # Increased from 10

  max_attempts.times do |attempt|
    Rails.logger.info("=== MealPlanGenerator: #{meal_type} - Attempt #{attempt + 1}/#{max_attempts}")

    # Randomly select foods
    foods_with_grams = randomly_select_foods(category_ids)

    # Check feasibility before attempting optimization
    coefficients = extract_coefficients(foods_with_grams)
    unless check_feasibility(foods_with_grams, coefficients, target_carbs, target_protein, target_fat)
      Rails.logger.info("=== Infeasible food combination, trying different foods")
      next  # Skip optimization, try different foods
    end

    # Try to optimize portions
    if optimize_portions(foods_with_grams, target_carbs, target_protein, target_fat)
      # ... success handling ...
    end
  end

  # ... rest of function ...
end
```

**Why this helps:** Avoids wasting optimization attempts on food combinations that mathematically cannot hit targets. Fails fast and tries new foods instead.

**3.2 Increase Random Attempts to 30**

Simple but effective change:

```ruby
# In compose_meal_by_categories and compose_meal_by_foods:
max_attempts = 30  # Was: 10

# Also delay relaxation:
if attempt >= 20  # Was: max_attempts / 2 (which was 5)
  Rails.logger.info("=== MealPlanGenerator: #{meal_type} - Trying with relaxed constraints")
  # ... relaxed optimization ...
end
```

**Why this helps:** With only 10 attempts and premature relaxation at attempt 5, algorithm gives up too quickly. 30 attempts with relaxation at 20 gives more chances to find good solutions before compromising.

**3.3 Track Best Food Combinations**

Learn which food combinations work better:

```ruby
# Add to MealPlanGenerator class:
def initialize(user:, name:, daily_macro_target:, daily_meal_structure:)
  @user = user
  @name = name
  @daily_macro_target = daily_macro_target
  @daily_meal_structure = daily_meal_structure
  @food_combination_scores = {}  # Track success of food combinations
end

def score_food_combination(foods_with_grams, error)
  combo_key = foods_with_grams.map { |f| f.food.id }.sort.join('-')

  # Store or update score (lower is better)
  if !@food_combination_scores[combo_key] || error < @food_combination_scores[combo_key]
    @food_combination_scores[combo_key] = error
  end
end

def try_successful_combination(category_ids)
  return nil if @food_combination_scores.empty?

  # Find best previous combination that used these categories
  best_combo = @food_combination_scores.min_by { |k, v| v }
  return nil unless best_combo

  combo_key, error = best_combo
  food_ids = combo_key.split('-').map(&:to_i)

  # Check if these foods are still valid for current categories
  foods = Food.where(id: food_ids).includes(:food_category)
  return nil unless foods.length == category_ids.length

  # Recreate food combination
  foods.map { |f| FoodWithGrams.new(food: f, grams: 0) }
end

# Use in compose_meal_by_categories:
def compose_meal_by_categories(meal_type, meal_structure_item, target_carbs, target_protein, target_fat)
  category_ids = meal_structure_item.food_category_ids
  max_attempts = 30

  max_attempts.times do |attempt|
    # Occasionally reuse successful combinations
    foods_with_grams = if attempt > 0 && attempt % 5 == 0 && rand < 0.3
      try_successful_combination(category_ids) || randomly_select_foods(category_ids)
    else
      randomly_select_foods(category_ids)
    end

    # ... optimization attempt ...

    # Score this combination
    if foods_with_grams
      error = calculate_total_error(foods_with_grams, target_carbs, target_protein, target_fat)
      score_food_combination(foods_with_grams, error)
    end
  end

  # ... rest of function ...
end
```

**Why this helps:** If attempt 7 found a good combination but didn't quite converge, we can retry it with different initialization in attempt 15. Learns across attempts instead of treating each independently.

### Priority 4: Advanced Techniques

**4.1 Constraint Relaxation Only as Last Resort**

Delay relaxation to give more attempts with proper constraints:

```ruby
# In compose_meal_by_categories:
max_attempts = 30

max_attempts.times do |attempt|
  # ... food selection and feasibility check ...

  # Try standard optimization
  if optimize_portions(foods_with_grams, target_carbs, target_protein, target_fat)
    # Success!
    return meal_result
  end

  # Try with relaxed constraints after 20 attempts (was: 5)
  if attempt >= 20
    Rails.logger.info("=== MealPlanGenerator: #{meal_type} - Trying with relaxed constraints")
    if optimize_portions(foods_with_grams, target_carbs, target_protein, target_fat, relaxed: true)
      # Success with relaxed
      return meal_result
    end
  end
end

# Last resort with very relaxed constraints (only if all 30 attempts failed)
Rails.logger.info("=== MealPlanGenerator: #{meal_type} - Last attempt with very relaxed constraints")
# ... last resort logic ...
```

**Why this helps:** Premature relaxation at attempt 5 means algorithm accepts suboptimal solutions too quickly. Delaying to attempt 20 gives Priority 1-3 improvements more chances to find proper solution.

**4.2 Per-Macro Tolerance Checking**

Identify which specific macros are failing:

```ruby
def identify_failing_macros(actual_macros, target_carbs, target_protein, target_fat, tolerance)
  failures = []

  failures << :protein if (actual_macros[:protein] - target_protein).abs > tolerance
  failures << :carbs if (actual_macros[:carbs] - target_carbs).abs > tolerance
  failures << :fat if (actual_macros[:fat] - target_fat).abs > tolerance

  failures
end

# Use in optimization loop:
def optimize_portions_targeted(foods_with_grams, target_carbs, target_protein, target_fat, relaxed: false, last_resort: false)
  # ... normal optimization ...

  # After MAX_ITERATIONS, check what failed
  actual_macros = calculate_macros(foods_with_grams)
  failures = identify_failing_macros(actual_macros, target_carbs, target_protein, target_fat, tolerance)

  if failures == [:protein]
    Rails.logger.info("=== Only protein failing - applying protein-focused correction")

    # Increase portions of high-protein foods specifically
    foods_with_grams.each_with_index do |item, i|
      protein_density = coefficients[i][:protein]
      if protein_density > 0.15  # High protein food
        # Try increasing by 20g
        item.grams = [item.grams + 20, MAX_PORTION_SIZE].min
      end
    end

    # Recheck
    actual_macros = calculate_macros(foods_with_grams)
  end

  # ... return success/failure ...
end
```

**Why this helps:** If protein is the only failing macro (common in your case), we can apply targeted fixes like increasing just protein-dense food portions, rather than generic relaxation.

**4.3 Hybrid Approach: Gradient Descent + Local Search**

Refine solution with local search after gradient descent:

```ruby
def local_search_refinement(foods_with_grams, coefficients, target_carbs, target_protein, target_fat)
  best_error = calculate_total_error_value(foods_with_grams, coefficients, target_carbs, target_protein, target_fat)
  improved = true

  # Keep trying to improve until no improvement found
  while improved
    improved = false

    foods_with_grams.length.times do |i|
      original_grams = foods_with_grams[i].grams
      best_grams = original_grams

      # Try small adjustments: ±5g, ±10g, ±20g
      [-20, -10, -5, 5, 10, 20].each do |delta|
        test_grams = original_grams + delta

        # Skip if out of bounds
        next if test_grams < MIN_PORTION_SIZE || test_grams > MAX_PORTION_SIZE

        # Test this adjustment
        foods_with_grams[i].grams = test_grams
        test_error = calculate_total_error_value(foods_with_grams, coefficients, target_carbs, target_protein, target_fat)

        if test_error < best_error
          best_error = test_error
          best_grams = test_grams
          improved = true
        end
      end

      # Apply best adjustment for this food
      foods_with_grams[i].grams = best_grams
    end
  end

  Rails.logger.info("=== Local search refinement reduced error to #{best_error.round(2)}")
end

# Use after gradient descent:
def optimize_portions(foods_with_grams, target_carbs, target_protein, target_fat, relaxed: false, last_resort: false)
  # ... run gradient descent ...

  # If close but not quite there, try local search refinement
  actual_macros = calculate_macros(foods_with_grams)
  if !within_tolerance && calculate_total_error_value(...) < tolerance * 1.5
    Rails.logger.info("=== Applying local search refinement")
    local_search_refinement(foods_with_grams, coefficients, target_carbs, target_protein, target_fat)

    # Recheck tolerance
    actual_macros = calculate_macros(foods_with_grams)
    within_tolerance = check_within_tolerance(actual_macros, target_carbs, target_protein, target_fat, tolerance)
  end

  within_tolerance
end
```

**Why this helps:** Gradient descent might get stuck at salmon=103g when salmon=105g would work. Local search tries small discrete adjustments that gradient descent might miss.

## Recommended Implementation Order

### Week 1: Critical Fixes (Priority 1)
These have the highest impact and should address most protein shortfall issues:

1. **Smart initialization (1.1)** - Start protein sources at 150g instead of 100g
   - Modify `optimize_portions` method around line 344-346
   - Add `initialize_portions_smart` helper method

2. **Weighted error function (1.2)** - Give protein 2x weight when target is high
   - Modify error calculation around line 370
   - Add `calculate_weighted_error` helper method
   - Update gradient calculation around line 383-386

3. **Multiple random restarts (1.3)** - Try 5-10 different starting points
   - Refactor `optimize_portions` into `optimize_with_multiple_restarts` and `optimize_portions_once`
   - Call from `compose_meal_by_categories` around line 154

**Expected outcome:** Should fix most cases where protein comes up 15g short.

### Week 2: Optimization Improvements (Priority 2)
Make optimization more efficient:

1. **Adaptive learning rate (2.1)** - Start at 1.0, decay over time, add momentum
   - Modify optimization loop around line 360-392
   - Replace fixed LEARNING_RATE with decay formula

2. **Convergence detection (2.2)** - Stop when improvement plateaus
   - Add improvement tracking in optimization loop
   - Break early when plateau detected

3. **Increase max attempts (3.2)** - From 10 to 30
   - Change line 145: `max_attempts = 30`
   - Change relaxation threshold line 169: `if attempt >= 20`

**Expected outcome:** Faster convergence, fewer wasted iterations, more attempts to find solution.

### Week 3: Advanced Features (Priority 3 & 4)
Polish and edge cases:

1. **Feasibility pre-check (3.1)** - Validate food combinations before optimizing
   - Add `check_feasibility` method
   - Call before optimization attempts

2. **Simulated annealing (2.3)** - Periodic random perturbations
   - Add perturbation logic to optimization loop every 30 iterations

3. **Constraint relaxation delay (4.1)** - Only as last resort
   - Already covered by increasing max_attempts to 30 and moving relaxation to attempt 20

**Expected outcome:** Avoid impossible food combinations, better exploration of solution space.

### Week 4: Testing and Refinement
Validate improvements and tune hyperparameters:

1. **Test on problematic meal plans**
   - Regenerate meal plan #13 multiple times
   - Test with various macro targets (especially high protein: 60g+)
   - Test with different meal structures

2. **Tune hyperparameters**
   - Protein weight (currently 2.0, try 1.5-3.0)
   - Smart initialization portions (protein: 150g, try 130-180g)
   - Learning rate decay (currently 0.95, try 0.90-0.97)
   - Number of restarts (currently 5, try 3-10)

3. **Add comprehensive logging**
   - Log initial portions vs final portions
   - Log which attempt succeeded
   - Log error progression over iterations
   - Log which foods consistently appear in successful solutions

**Expected outcome:** Robust algorithm that consistently hits protein targets, with tuned parameters for optimal performance.

## Success Metrics

After implementing improvements, measure success by:

1. **Protein achievement rate** - Percentage of meal plans within tolerance (±8g) on protein
   - Current: ~60-70% estimated
   - Target: >95%

2. **Average protein shortfall** - When protein is missed, by how much
   - Current: ~15g average shortfall
   - Target: <5g average shortfall

3. **Attempts to success** - How many random attempts before finding solution
   - Current: Often hits max 10 attempts
   - Target: Success within 10 attempts for 90% of meals

4. **Relaxation rate** - Percentage of meals requiring relaxed constraints
   - Current: High (many hit last_resort)
   - Target: <10% require relaxation

5. **Convergence speed** - Average iterations to convergence
   - Current: Often hits 200 max iterations
   - Target: Average <100 iterations

## Additional Recommendations

### Code Organization
Consider extracting optimization logic into separate service:
- `MealPlanGenerator` handles database, meal distribution, food selection
- `PortionOptimizer` handles just the optimization math
- `OptimizationStrategy` module with different strategies (gradient_descent, simulated_annealing, hybrid)

### Configuration
Make hyperparameters configurable:
```ruby
# config/meal_optimization.yml
optimization:
  max_iterations: 200
  learning_rate:
    initial: 1.0
    decay: 0.95
  protein_weight:
    low_target: 1.5   # when target < 50g
    high_target: 2.0  # when target >= 50g
  smart_initialization:
    protein_food_grams: 150
    fat_food_grams: 50
    vegetable_grams: 100
  attempts:
    max_standard: 30
    relaxation_threshold: 20
  restarts:
    num_restarts: 5
```

### Monitoring
Add metrics collection for algorithm performance:
```ruby
# Track success rates in ApplicationRecord or separate metrics service
after_create :log_optimization_metrics

def log_optimization_metrics
  metrics = {
    protein_achieved: (actual_protein_grams - target_protein_grams).abs <= MACRO_TOLERANCE_GRAMS,
    protein_error: (actual_protein_grams - target_protein_grams).abs,
    attempts_taken: self.metadata[:attempts],
    relaxed: self.metadata[:relaxed],
    # ...
  }

  Rails.logger.info("OPTIMIZATION_METRICS: #{metrics.to_json}")
end
```

### Testing Strategy
Add specific tests for optimization scenarios:
```ruby
# spec/services/meal_plan_generator_spec.rb

describe "high protein targets" do
  it "achieves 60g protein target with keto foods" do
    # Test with meal structure similar to meal plan #13
    # Should pass with Priority 1 improvements
  end

  it "achieves 80g protein target with standard foods" do
    # More challenging test
  end
end

describe "optimization convergence" do
  it "converges within 100 iterations for typical meals" do
    # Monitor iteration count
  end

  it "detects plateaus and stops early" do
    # Test convergence detection
  end
end
```

## Conclusion

The protein shortfall issue is solvable through systematic improvements to the optimization algorithm. The Priority 1 improvements (smart initialization, weighted error, multiple restarts) directly address the root cause identified in the manual solution analysis: the algorithm starts and converges in the wrong region of the solution space (75-80g protein portions) instead of exploring the successful region (130g+ protein portions).

Implementing these improvements in the recommended order will progressively increase the algorithm's success rate from ~60-70% to >95% for hitting protein targets.
