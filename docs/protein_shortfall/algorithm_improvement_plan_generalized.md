# Algorithm Improvement Plan: Macro-Agnostic Optimization

## Problem Overview

The algorithm in `app/services/meal_plan_generator.rb` regularly fails to achieve macro targets. For example:
- **Keto diet (meal plan #13):** 45g protein achieved vs 60g target (-15.4g difference)
- The algorithm hits carbs and fat but misses protein

This problem is not diet-specific - the algorithm could just as easily:
- Miss carb targets for a carb-loading endurance athlete
- Miss fat targets for a high-fat ketogenic diet
- Miss protein targets for a bodybuilder's high-protein diet

The manual solution analysis at `docs/manual-solution-2meal.md` proves that the same foods CAN achieve the targets with proper portion sizes (130g+ for protein sources vs algorithm's ~77g). This is an **optimization problem**, not a feasibility problem.

## Core Insight: The Real Problem

The algorithm doesn't have a "protein problem" - it has a **convergence problem**. It gets stuck in local minima before finding solutions that satisfy all macros. The issue manifests as protein shortfall in keto diets, but would manifest as carb shortfall in high-carb diets, or fat shortfall in other scenarios.

## Analysis of Algorithm Issues

I've identified **12 critical problems** in `app/services/meal_plan_generator.rb`:

### Root Causes of Macro Achievement Failures

**1. Poor Initialization Strategy (lines 344-346)**
- Equal portions at ~100g per food (300g / n foods)
- Doesn't consider macro density of different foods
- Foods with high density in the **target macro** need larger initial portions
- Example: For high-protein diet, protein-dense foods start too small; for high-carb diet, carb-dense foods start too small

**2. Uniform Learning Rate (line 14, 389)**
- Fixed `LEARNING_RATE = 0.5` applies same adjustment to all foods
- Foods that are primary contributors to deficient macros need larger adjustments
- Causes premature convergence before all targets are met

**3. Isotropic Error Function (lines 367-370)**
- Treats all macro errors equally: `total_error = carb_error² + protein_error² + fat_error²`
- A 15g shortage in ANY macro should be weighted based on:
  - How hard that macro is to achieve with selected foods
  - How far the macro is from its target (proportionally)
  - Which macro is the primary bottleneck

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
- Should initialize foods that are dense in **currently-deficient macros** at larger portions
- Should initialize foods that are dense in **already-satisfied macros** at smaller portions

**8. No Macro Priority in Gradient**
- Gradient treats all macro errors equally (lines 383-386)
- Should amplify gradient for whichever macro is most deficient
- Current gradient: `2 * (carb_error * c + protein_error * p + fat_error * f)`
- Better: dynamically weighted gradient based on which macros are furthest from targets

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

## Macro-Agnostic Improvement Plan

### Priority 1: Critical Fixes (Highest Impact)

**1.1 Smart Initialization Based on Scarcity**

Instead of equal portions, initialize based on which macros are SCARCE (hard to achieve with selected foods):

```ruby
def initialize_portions_smart(foods_with_grams, coefficients, target_carbs, target_protein, target_fat)
  portions = []

  # Calculate how much of each macro is available if all foods at MAX_PORTION_SIZE
  max_available_carbs = coefficients.sum { |c| c[:carbs] * MAX_PORTION_SIZE }
  max_available_protein = coefficients.sum { |c| c[:protein] * MAX_PORTION_SIZE }
  max_available_fat = coefficients.sum { |c| c[:fat] * MAX_PORTION_SIZE }

  # Calculate scarcity ratios: target / available
  # Higher ratio = more scarce = harder to achieve
  carb_scarcity = max_available_carbs > 0 ? (target_carbs / max_available_carbs) : 0
  protein_scarcity = max_available_protein > 0 ? (target_protein / max_available_protein) : 0
  fat_scarcity = max_available_fat > 0 ? (target_fat / max_available_fat) : 0

  # Identify which macro is most scarce
  scarcities = { carbs: carb_scarcity, protein: protein_scarcity, fat: fat_scarcity }
  primary_scarce_macro = scarcities.max_by { |k, v| v }.first

  Rails.logger.info("=== Scarcity analysis: C:#{carb_scarcity.round(2)} P:#{protein_scarcity.round(2)} F:#{fat_scarcity.round(2)} - Primary: #{primary_scarce_macro}")

  foods_with_grams.each_with_index do |item, i|
    carb_density = coefficients[i][:carbs]
    protein_density = coefficients[i][:protein]
    fat_density = coefficients[i][:fat]

    # Calculate how much each food contributes to the SCARCE macro
    # Foods that provide the scarce macro should start larger
    contribution_score = case primary_scarce_macro
    when :protein
      protein_density > 0.15 ? :high : (protein_density > 0.05 ? :medium : :low)
    when :carbs
      carb_density > 0.15 ? :high : (carb_density > 0.05 ? :medium : :low)
    when :fat
      fat_density > 0.80 ? :high : (fat_density > 0.30 ? :medium : :low)
    end

    # Initialize portions based on contribution to scarce macro
    portions[i] = case contribution_score
    when :high
      150.0  # Foods that provide the scarce macro start larger
    when :medium
      100.0  # Foods with moderate contribution start medium
    when :low
      60.0   # Foods with low contribution start smaller
    end
  end

  portions
end
```

**Why scarcity-based initialization works:**

**Example 1: Keto diet (20C/60P/180F) with salmon, chicken, oil, vegetables**
- Max available: 200g carbs, 120g protein, 600g fat
- Scarcity ratios: 20/200=0.10, 60/120=**0.50**, 180/600=0.30
- **Protein is most scarce** (ratio 0.50) → salmon and chicken start at 150g
- This correctly identifies protein as the bottleneck, even though fat has more grams!

**Example 2: Bodybuilder diet (200C/200P/60F) with chicken, rice, vegetables**
- Max available: 400g carbs, 150g protein, 100g fat
- Scarcity ratios: 200/400=0.50, 200/150=**1.33**, 60/100=0.60
- **Protein is most scarce** (ratio 1.33) → chicken starts at 150g
- Protein is hardest to achieve relative to what's available

**Example 3: Endurance athlete (400C/100P/80F) with pasta, chicken, vegetables**
- Max available: 500g carbs, 150g protein, 120g fat
- Scarcity ratios: 400/500=**0.80**, 100/150=0.67, 80/120=0.67
- **Carbs are most scarce** (ratio 0.80) → pasta starts at 150g
- Carbs need large portions relative to what's available

**Example 4: Balanced diet (150C/150P/150F) with balanced food selection**
- All scarcity ratios similar → all foods start closer to 100g

**Key insight:** Scarcity ratio tells us which macro requires foods to be at larger portions to satisfy the target. A ratio of 0.50 means "we need to use 50% of available capacity", while 1.0 means "we need to max out all foods".

**1.2 Dynamic Weighted Error Function**

Replace isotropic error with dynamically weighted error based on proportional deficiency:

```ruby
def calculate_dynamic_weighted_error(carb_error, protein_error, fat_error,
                                     target_carbs, target_protein, target_fat)
  # Calculate proportional errors (what % of target are we off by?)
  carb_prop_error = target_carbs > 0 ? (carb_error.abs / target_carbs) : 0
  protein_prop_error = target_protein > 0 ? (protein_error.abs / target_protein) : 0
  fat_prop_error = target_fat > 0 ? (fat_error.abs / target_fat) : 0

  # Weight macros by how far off they are proportionally
  # The macro that's furthest off (proportionally) gets highest weight
  max_prop_error = [carb_prop_error, protein_prop_error, fat_prop_error].max

  # Normalize weights: macro with highest proportional error gets weight 2.0,
  # others get weight proportional to their error
  carb_weight = max_prop_error > 0 ? (1.0 + carb_prop_error / max_prop_error) : 1.0
  protein_weight = max_prop_error > 0 ? (1.0 + protein_prop_error / max_prop_error) : 1.0
  fat_weight = max_prop_error > 0 ? (1.0 + fat_prop_error / max_prop_error) : 1.0

  # Calculate weighted squared error
  (carb_weight * carb_error**2) +
  (protein_weight * protein_error**2) +
  (fat_weight * fat_error**2)
end

# Update gradient calculation accordingly:
def calculate_dynamic_weighted_gradient(i, carb_error, protein_error, fat_error,
                                       coefficients, target_carbs, target_protein, target_fat)
  # Same weight calculation as above
  carb_prop_error = target_carbs > 0 ? (carb_error.abs / target_carbs) : 0
  protein_prop_error = target_protein > 0 ? (protein_error.abs / target_protein) : 0
  fat_prop_error = target_fat > 0 ? (fat_error.abs / target_fat) : 0

  max_prop_error = [carb_prop_error, protein_prop_error, fat_prop_error].max

  carb_weight = max_prop_error > 0 ? (1.0 + carb_prop_error / max_prop_error) : 1.0
  protein_weight = max_prop_error > 0 ? (1.0 + protein_prop_error / max_prop_error) : 1.0
  fat_weight = max_prop_error > 0 ? (1.0 + fat_prop_error / max_prop_error) : 1.0

  2 * (
    carb_weight * carb_error * coefficients[i][:carbs] +
    protein_weight * protein_error * coefficients[i][:protein] +
    fat_weight * fat_error * coefficients[i][:fat]
  )
end
```

**Why this works for any diet:**
- If carbs are 50% off target but protein is only 10% off, carbs get ~2x higher weight
- Dynamically adjusts as optimization progresses
- Works regardless of which macro is the problem
- Prevents "two macros perfect, one macro terrible" solutions

**Example scenarios:**
- **Keto diet** (20C/60P/180F): If achieving 20C/45P/180F, protein is 25% off while carbs/fat are perfect → protein gets 2.0 weight
- **High-carb athlete** (400C/100P/80F): If achieving 300C/100P/80F, carbs are 25% off → carbs get 2.0 weight
- **Balanced diet** (150C/150P/150F): All macros weighted equally if all equally off

**1.3 Multiple Random Restarts (5-10 restarts)**

Try optimization from multiple starting points:

```ruby
def optimize_with_multiple_restarts(foods_with_grams, target_carbs, target_protein, target_fat,
                                   num_restarts: 5, relaxed: false, last_resort: false)
  best_solution = nil
  best_error = Float::INFINITY
  best_foods = nil

  num_restarts.times do |restart|
    Rails.logger.info("=== Optimization restart #{restart + 1}/#{num_restarts}")

    # Create fresh copy of foods
    test_foods = foods_with_grams.map { |f| FoodWithGrams.new(food: f.food, grams: 0) }

    # Run optimization with this restart
    if optimize_portions_once(test_foods, target_carbs, target_protein, target_fat,
                              restart_seed: restart, relaxed: relaxed, last_resort: last_resort)
      # Calculate error for this solution
      actual_macros = calculate_macros(test_foods)
      current_error = calculate_dynamic_weighted_error(
        target_carbs - actual_macros[:carbs],
        target_protein - actual_macros[:protein],
        target_fat - actual_macros[:fat],
        target_carbs, target_protein, target_fat
      )

      # Keep best solution
      if current_error < best_error
        best_solution = test_foods
        best_error = current_error
        Rails.logger.info("=== New best solution found at restart #{restart + 1}, error: #{best_error.round(2)}")
      end
    end
  end

  # If we found any solution, copy it back
  if best_solution
    foods_with_grams.each_with_index do |item, i|
      item.grams = best_solution[i].grams
    end
    return true
  end

  false
end

def optimize_portions_once(foods_with_grams, target_carbs, target_protein, target_fat,
                          restart_seed: 0, relaxed: false, last_resort: false)
  # Extract coefficients
  coefficients = foods_with_grams.map do |item|
    macros = NutrientLookupService.macronutrients_for(item.food)
    {
      carbs: (macros[:carbohydrates] || 0) / 100.0,
      protein: (macros[:protein] || 0) / 100.0,
      fat: (macros[:fat] || 0) / 100.0
    }
  end

  # Initialize portions (smart initialization)
  portions = initialize_portions_smart(foods_with_grams, coefficients, target_carbs, target_protein, target_fat)

  # Add randomization for restarts > 0
  if restart_seed > 0
    portions = portions.map do |p|
      variation_factor = 0.7 + rand * 0.6  # Random between 0.7x and 1.3x
      new_p = p * variation_factor
      [[new_p, MIN_PORTION_SIZE].max, MAX_PORTION_SIZE].min
    end
  end

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

  # Run gradient descent optimization...
  # (rest of optimization logic - see Priority 2 for improvements)

  # ... gradient descent loop here ...

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

**Why this works for any diet:**
- Tries 5 different starting points in the solution space
- One might start with large protein portions, another with large carb portions
- Increases likelihood of finding the optimal region regardless of diet type
- Macro-agnostic: explores different portion combinations without bias

### Priority 2: Optimization Improvements

**2.1 Adaptive Learning Rate with Momentum**

Replace fixed learning rate with adaptive version:

```ruby
def optimize_portions_adaptive(foods_with_grams, target_carbs, target_protein, target_fat,
                               restart_seed: 0, relaxed: false, last_resort: false)
  # ... initialization code from above ...

  n = foods_with_grams.length

  # Momentum variables
  velocity = Array.new(n, 0.0)
  momentum = 0.9
  base_learning_rate = 1.0  # Start larger than current 0.5

  MAX_ITERATIONS.times do |iter|
    # Calculate current macros and errors
    current_carbs = portions.each_with_index.sum { |p, i| p * coefficients[i][:carbs] }
    current_protein = portions.each_with_index.sum { |p, i| p * coefficients[i][:protein] }
    current_fat = portions.each_with_index.sum { |p, i| p * coefficients[i][:fat] }

    carb_error = target_carbs - current_carbs
    protein_error = target_protein - current_protein
    fat_error = target_fat - current_fat

    # Calculate dynamic weighted error
    total_error = calculate_dynamic_weighted_error(
      carb_error, protein_error, fat_error,
      target_carbs, target_protein, target_fat
    )

    # Save best solution
    if total_error < best_error
      best_error = total_error
      best_portions = portions.dup

      # Early exit if within tolerance
      break if Math.sqrt(best_error) < tolerance
    end

    # Adaptive learning rate: decay over time
    current_lr = base_learning_rate * (0.95 ** (iter / 20.0))

    # Update portions using dynamic weighted gradient with momentum
    n.times do |i|
      gradient = calculate_dynamic_weighted_gradient(
        i, carb_error, protein_error, fat_error,
        coefficients, target_carbs, target_protein, target_fat
      )

      # Apply momentum
      velocity[i] = momentum * velocity[i] + current_lr * gradient
      portions[i] += velocity[i]

      # Clamp to bounds
      portions[i] = [[portions[i], MIN_PORTION_SIZE].max, MAX_PORTION_SIZE].min
    end
  end

  # ... apply best solution and return ...
end
```

**Why this works for any diet:**
- Larger initial learning rate explores solution space more aggressively
- Decay prevents overshooting as we approach optimal solution
- Momentum helps escape local minima regardless of which macro is problematic
- No diet-specific assumptions

**2.2 Convergence Detection with Plateau Threshold**

Stop iterating when improvement plateaus:

```ruby
def optimize_portions_with_convergence(foods_with_grams, target_carbs, target_protein, target_fat,
                                       restart_seed: 0, relaxed: false, last_resort: false)
  # ... initialization and setup ...

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

  # ... apply best solution and return ...
end
```

**Why this works for any diet:**
- Detects when optimizer is stuck regardless of which macro is the problem
- Saves iterations for trying new food combinations
- Macro-agnostic convergence detection

**2.3 Simulated Annealing for Exploration**

Add occasional random perturbations to escape local minima:

```ruby
def optimize_portions_with_annealing(foods_with_grams, target_carbs, target_protein, target_fat,
                                     restart_seed: 0, relaxed: false, last_resort: false)
  # ... initialization and setup ...

  MAX_ITERATIONS.times do |iter|
    # ... normal gradient descent step ...

    # Periodically apply simulated annealing perturbation
    # But only in first 80% of iterations
    if iter % 30 == 0 && iter < MAX_ITERATIONS * 0.8
      temperature = 20.0 * (1.0 - iter.to_f / MAX_ITERATIONS)  # Decay temperature

      # Randomly perturb ALL portions to explore nearby regions
      portions = portions.map do |p|
        perturbation = rand(-temperature..temperature)
        new_p = p + perturbation
        [[new_p, MIN_PORTION_SIZE].max, MAX_PORTION_SIZE].min
      end

      Rails.logger.debug("=== Applied annealing perturbation at iter #{iter} (temp: #{temperature.round(1)})")
    end
  end

  # ... apply best solution and return ...
end
```

**Why this works for any diet:**
- Random jumps help escape local minima regardless of diet type
- Temperature decay means large jumps early (exploration), small jumps later (refinement)
- No assumptions about which macro is problematic

### Priority 3: Food Selection Improvements

**3.1 Feasibility Pre-Check**

Validate if selected foods can possibly hit targets:

```ruby
def check_feasibility(foods_with_grams, coefficients, target_carbs, target_protein, target_fat)
  # Calculate max possible macros with all foods at MAX_PORTION_SIZE
  max_carbs = coefficients.sum { |c| c[:carbs] * MAX_PORTION_SIZE }
  max_protein = coefficients.sum { |c| c[:protein] * MAX_PORTION_SIZE }
  max_fat = coefficients.sum { |c| c[:fat] * MAX_PORTION_SIZE }

  # Calculate min possible (at MIN_PORTION_SIZE)
  min_carbs = coefficients.sum { |c| c[:carbs] * MIN_PORTION_SIZE }
  min_protein = coefficients.sum { |c| c[:protein] * MIN_PORTION_SIZE }
  min_fat = coefficients.sum { |c| c[:fat] * MIN_PORTION_SIZE }

  # Check if targets are within feasible range (with 10% buffer for tolerance)
  feasible = true

  # Check maximums: can we provide ENOUGH of each macro?
  if target_carbs > max_carbs * 0.9
    Rails.logger.warn("=== Carbs target #{target_carbs.round}g may be infeasible (max: #{max_carbs.round}g)")
    feasible = false
  end

  if target_protein > max_protein * 0.9
    Rails.logger.warn("=== Protein target #{target_protein.round}g may be infeasible (max: #{max_protein.round}g)")
    feasible = false
  end

  if target_fat > max_fat * 0.9
    Rails.logger.warn("=== Fat target #{target_fat.round}g may be infeasible (max: #{max_fat.round}g)")
    feasible = false
  end

  # Check minimums: do we have TOO MUCH of a macro we're trying to avoid?
  if min_carbs > target_carbs * 1.5
    Rails.logger.warn("=== Minimum carbs #{min_carbs.round}g exceeds target #{target_carbs.round}g by too much")
    feasible = false
  end

  if min_protein > target_protein * 1.5
    Rails.logger.warn("=== Minimum protein #{min_protein.round}g exceeds target #{target_protein.round}g by too much")
    feasible = false
  end

  if min_fat > target_fat * 1.5
    Rails.logger.warn("=== Minimum fat #{min_fat.round}g exceeds target #{target_fat.round}g by too much")
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

    # Extract coefficients
    coefficients = foods_with_grams.map do |item|
      macros = NutrientLookupService.macronutrients_for(item.food)
      {
        carbs: (macros[:carbohydrates] || 0) / 100.0,
        protein: (macros[:protein] || 0) / 100.0,
        fat: (macros[:fat] || 0) / 100.0
      }
    end

    # Check feasibility before attempting optimization
    unless check_feasibility(foods_with_grams, coefficients, target_carbs, target_protein, target_fat)
      Rails.logger.info("=== Infeasible food combination, trying different foods")
      next  # Skip optimization, try different foods
    end

    # Try to optimize portions using multiple restarts
    if optimize_with_multiple_restarts(foods_with_grams, target_carbs, target_protein, target_fat)
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

    # Try with relaxed constraints after 20 attempts (was: 5)
    if attempt >= 20
      Rails.logger.info("=== MealPlanGenerator: #{meal_type} - Trying with relaxed constraints")
      if optimize_with_multiple_restarts(foods_with_grams, target_carbs, target_protein, target_fat, relaxed: true)
        # ... success handling ...
      end
    end
  end

  # ... last resort logic ...
end
```

**Why this works for any diet:**
- Checks feasibility for ALL three macros, not just protein
- Fails fast on impossible food combinations (e.g., trying to get 400g carbs from meat and cheese)
- Works for keto, high-carb, high-protein, or balanced diets

**3.2 Increase Random Attempts to 30**

```ruby
max_attempts = 30  # Up from 10

# Also delay relaxation:
if attempt >= 20  # Was: max_attempts / 2 (which was 5)
  # Try relaxed constraints
end
```

**3.3 Track Best Food Combinations Across Attempts**

```ruby
# Add to MealPlanGenerator class:
def initialize(user:, name:, daily_macro_target:, daily_meal_structure:)
  @user = user
  @name = name
  @daily_macro_target = daily_macro_target
  @daily_meal_structure = daily_meal_structure
  @food_combination_scores = {}  # Track success of food combinations
end

def score_food_combination(foods_with_grams, target_carbs, target_protein, target_fat)
  combo_key = foods_with_grams.map { |f| f.food.id }.sort.join('-')

  actual_macros = calculate_macros(foods_with_grams)
  error = calculate_dynamic_weighted_error(
    target_carbs - actual_macros[:carbs],
    target_protein - actual_macros[:protein],
    target_fat - actual_macros[:fat],
    target_carbs, target_protein, target_fat
  )

  # Store or update score (lower error is better)
  if !@food_combination_scores[combo_key] || error < @food_combination_scores[combo_key]
    @food_combination_scores[combo_key] = error
  end
end
```

**Why this works for any diet:**
- Uses dynamic weighted error, so learns which foods work for ANY macro target
- If carbs are the problem, it learns which high-carb foods help
- If protein is the problem, it learns which high-protein foods help
- Macro-agnostic learning

### Priority 4: Advanced Techniques

**4.1 Per-Macro Tolerance Checking with Targeted Fixes**

```ruby
def identify_failing_macros(actual_macros, target_carbs, target_protein, target_fat, tolerance)
  failures = []

  failures << :carbs if (actual_macros[:carbs] - target_carbs).abs > tolerance
  failures << :protein if (actual_macros[:protein] - target_protein).abs > tolerance
  failures << :fat if (actual_macros[:fat] - target_fat).abs > tolerance

  failures
end

def apply_targeted_fix(foods_with_grams, coefficients, failures, target_carbs, target_protein, target_fat, tolerance)
  # If only ONE macro is failing, try targeted fix
  return false unless failures.length == 1

  failing_macro = failures.first
  actual_macros = calculate_macros(foods_with_grams)

  case failing_macro
  when :carbs
    # Increase portions of high-carb foods
    foods_with_grams.each_with_index do |item, i|
      if coefficients[i][:carbs] > 0.15  # High carb density
        shortage = target_carbs - actual_macros[:carbs]
        # Increase this food to provide some of the shortage
        increase = (shortage / coefficients[i][:carbs]).clamp(0, 30)
        item.grams = [item.grams + increase, MAX_PORTION_SIZE].min
      end
    end
    Rails.logger.info("=== Applied targeted fix for carbs")

  when :protein
    # Increase portions of high-protein foods
    foods_with_grams.each_with_index do |item, i|
      if coefficients[i][:protein] > 0.15  # High protein density
        shortage = target_protein - actual_macros[:protein]
        increase = (shortage / coefficients[i][:protein]).clamp(0, 30)
        item.grams = [item.grams + increase, MAX_PORTION_SIZE].min
      end
    end
    Rails.logger.info("=== Applied targeted fix for protein")

  when :fat
    # Increase portions of high-fat foods
    foods_with_grams.each_with_index do |item, i|
      if coefficients[i][:fat] > 0.30  # High fat density
        shortage = target_fat - actual_macros[:fat]
        increase = (shortage / coefficients[i][:fat]).clamp(0, 30)
        item.grams = [item.grams + increase, MAX_PORTION_SIZE].min
      end
    end
    Rails.logger.info("=== Applied targeted fix for fat")
  end

  # Check if fix worked
  actual_macros = calculate_macros(foods_with_grams)
  (actual_macros[:carbs] - target_carbs).abs <= tolerance &&
  (actual_macros[:protein] - target_protein).abs <= tolerance &&
  (actual_macros[:fat] - target_fat).abs <= tolerance
end
```

**Why this works for any diet:**
- Detects which specific macro is failing
- Applies targeted fix for THAT macro (carbs, protein, or fat)
- Works for any diet type - doesn't assume protein is the problem

## Critical Discovery: Business Requirement - Daily Tolerance, Not Per-Meal

During implementation, we discovered the **business requirement was being violated**:

**Business Requirement:** The tolerance (±8g) applies to the **entire day's macros**, not per meal.

**Previous Problem:** If you have 2 meals, each with ±8g tolerance:
- Meal 1: 30g target, achieves 22g (8g under, within per-meal tolerance ✓)
- Meal 2: 30g target, achieves 23g (7g under, within per-meal tolerance ✓)
- **Total:** 60g target, achieves 45g (**-15g, violates daily ±8g requirement** ✗)

**Solution Implemented:** Distributed tolerance system with daily validation

### How It Works:

**1. Distribute daily tolerance across meals:**
```ruby
num_meals = 2
per_meal_convergence_tolerance = MACRO_TOLERANCE_GRAMS / (2.0 * num_meals)  # 8 / (2*2) = ±2g
per_meal_acceptance_tolerance = MACRO_TOLERANCE_GRAMS / num_meals            # 8 / 2 = ±4g
```

**2. Each meal optimizes independently** with distributed tolerances:
- Convergence target: ±2g (optimizer aims for this)
- Acceptance range: ±4g (allows this if convergence not achievable)

**3. Validate daily totals after all meals composed:**
```ruby
# After composing all meals, sum actual macros
total_protein = meals.sum { |m| m[:actual_protein] }

# Check against DAILY tolerance (the business requirement)
daily_within_tolerance = (total_protein - daily_target_protein).abs <= MACRO_TOLERANCE_GRAMS

if !daily_within_tolerance
  # Retry composition with different food selections
end
```

**4. Retry up to 5 times if daily validation fails**

### Why This Works:

**For 2 meals with 60g protein target:**
- Each meal targets 30g protein
- Per-meal convergence: ±2g (aims for 28-32g per meal)
- Per-meal acceptance: ±4g (allows 26-34g per meal)
- **Worst case:** Both meals at 26g = 52g total (**within daily ±8g** ✓)

**For 3 meals with 60g protein target:**
- Each meal targets 20g protein
- Per-meal convergence: ±1.33g (aims for 18.67-21.33g per meal)
- Per-meal acceptance: ±2.67g (allows 17.33-22.67g per meal)
- **Worst case:** All meals at 17.33g = 52g total (**within daily ±8g** ✓)

### Key Benefits:

✅ **Guarantees business requirement** - Daily validation ensures ±8g daily tolerance is met
✅ **Independent meal composition** - Each meal still optimized separately
✅ **Scales with any tolerance value** - Uses `MACRO_TOLERANCE_GRAMS` constant throughout
✅ **Scales with number of meals** - Distribution formula adjusts automatically
✅ **Retries on failure** - If daily validation fails, tries different food combinations

## Recommended Implementation Order

### Week 1: Critical Fixes (Priority 1)
These have the highest impact and are fully macro-agnostic:

1. **Distributed tolerance system with daily validation** - Enforce business requirement
   - ✅ IMPLEMENTED: Distribute daily tolerance across meals (convergence = daily / (2 * num_meals), acceptance = daily / num_meals)
   - ✅ IMPLEMENTED: Daily validation loop - retries up to 5 times if daily totals exceed tolerance
   - ✅ IMPLEMENTED: Guarantees daily ±8g tolerance requirement is met

2. **Dynamic weighted error (1.2)** - Weight by proportional deficiency
   - ✅ IMPLEMENTED: `calculate_dynamic_weighted_error` method
   - ✅ IMPLEMENTED: `calculate_dynamic_weighted_gradient` method
   - ✅ IMPLEMENTED: Updated optimization loop to use dynamic weights

3. **Smart initialization (1.1)** - Initialize foods based on scarcity
   - TODO: Add `initialize_portions_smart` method
   - Uses scarcity ratios (target / max_available)

4. **Multiple random restarts (1.3)** - Try 5 different starting points
   - TODO: Refactor `optimize_portions` into `optimize_with_multiple_restarts` and `optimize_portions_once`

**Expected outcome:**
- ✅ Daily tolerance requirement guaranteed (±8g for entire day)
- Should work for ANY macro target distribution (keto, high-carb, high-protein, balanced)
- Should work for ANY number of meals (2, 3, 4+)
- Should work with ANY tolerance value (not hardcoded to 8g)

### Week 2: Optimization Improvements (Priority 2)

1. **Adaptive learning rate (2.1)** - Start at 1.0, decay, add momentum
2. **Convergence detection (2.2)** - Stop at plateaus
3. **Increase max attempts (3.2)** - From 10 to 30

**Expected outcome:** Faster convergence, more attempts to find solution.

### Week 3: Advanced Features (Priority 3 & 4)

1. **Feasibility pre-check (3.1)** - Check all three macros for feasibility
2. **Simulated annealing (2.3)** - Escape local minima
3. **Targeted fixes (4.1)** - Fix whichever macro is failing

**Expected outcome:** Handle edge cases, work with difficult food combinations.

### Week 4: Testing and Refinement

Test with diverse diet types:
1. **Keto diet** (20C/60P/180F) - Low carb, high fat, moderate protein
2. **Bodybuilder** (200C/200P/60F) - High protein, moderate carb, low fat
3. **Endurance athlete** (400C/100P/80F) - Very high carb, moderate protein, low fat
4. **Balanced USDA** (250C/100P/70F) - Roughly balanced
5. **Low-carb paleo** (80C/120P/100F) - Moderate protein/fat, low carb

For each, verify:
- All three macros are achieved within tolerance
- Doesn't favor one macro over others
- Works with various meal structures

## Success Metrics (Macro-Agnostic)

After implementing improvements, measure success by:

1. **Overall macro achievement rate** - Percentage of meal plans where ALL three macros within tolerance
   - Current: ~60-70% estimated
   - Target: >95%

2. **Per-macro achievement rate** - Track separately for carbs, protein, fat
   - Should be roughly equal across all three macros (~95% each)
   - If protein is 95% but carbs are 70%, algorithm still has bias

3. **Average shortfall by macro** - When each macro is missed, by how much
   - Current: ~15g for protein (unknown for carbs/fat)
   - Target: <5g average for all three macros

4. **Diet-type coverage** - Works across diet types
   - Test with keto, bodybuilder, endurance athlete, balanced diets
   - Should have similar success rates regardless of diet type

5. **Attempts to success** - How many random attempts before finding solution
   - Current: Often hits max 10 attempts
   - Target: Success within 10 attempts for 90% of meals

## Testing Strategy for Different Diet Types

```ruby
# spec/services/meal_plan_generator_spec.rb

describe "macro-agnostic optimization" do
  describe "keto diet (high fat, low carb, moderate protein)" do
    let(:macro_target) { create(:daily_macro_target, carbs_grams: 20, protein_grams: 60, fat_grams: 180) }

    it "achieves all three macros within tolerance" do
      result = generator.compose_meals
      expect(result[:actual_carbs]).to be_within(8).of(20)
      expect(result[:actual_protein]).to be_within(8).of(60)
      expect(result[:actual_fat]).to be_within(8).of(180)
    end
  end

  describe "bodybuilder diet (high protein, moderate carb, low fat)" do
    let(:macro_target) { create(:daily_macro_target, carbs_grams: 200, protein_grams: 200, fat_grams: 60) }

    it "achieves all three macros within tolerance" do
      result = generator.compose_meals
      expect(result[:actual_carbs]).to be_within(8).of(200)
      expect(result[:actual_protein]).to be_within(8).of(200)
      expect(result[:actual_fat]).to be_within(8).of(60)
    end
  end

  describe "endurance athlete (very high carb, moderate protein, low fat)" do
    let(:macro_target) { create(:daily_macro_target, carbs_grams: 400, protein_grams: 100, fat_grams: 80) }

    it "achieves all three macros within tolerance" do
      result = generator.compose_meals
      expect(result[:actual_carbs]).to be_within(8).of(400)
      expect(result[:actual_protein]).to be_within(8).of(100)
      expect(result[:actual_fat]).to be_within(8).of(80)
    end
  end

  describe "balanced USDA diet" do
    let(:macro_target) { create(:daily_macro_target, carbs_grams: 250, protein_grams: 100, fat_grams: 70) }

    it "achieves all three macros within tolerance" do
      result = generator.compose_meals
      expect(result[:actual_carbs]).to be_within(8).of(250)
      expect(result[:actual_protein]).to be_within(8).of(100)
      expect(result[:actual_fat]).to be_within(8).of(70)
    end
  end
end
```

## Key Principles for Macro-Agnostic Design

1. **Never hardcode macro priorities** - Use proportions and dynamic weighting
2. **All three macros are equally important** - Don't favor protein over carbs or fat
3. **Proportional thinking** - Being 10% off target matters more for 50g protein than 500g carbs
4. **Test with diverse diet types** - If it only works for keto, it's not macro-agnostic
5. **Dynamic adaptation** - Algorithm should discover which macro is hardest for current food selection

## Conclusion

The core insight is that this is NOT a "protein problem" - it's an **optimization convergence problem** that happens to manifest as protein shortfall in keto diets. The same algorithm would fail to achieve carb targets in high-carb diets or fat targets in other scenarios.

The solution is to make the algorithm **macro-agnostic** by:
1. Dynamically determining which macro is the primary target
2. Weighting errors by proportional deficiency (not absolute)
3. Exploring multiple starting points in the solution space
4. Testing across diverse diet types to ensure no built-in bias

This approach will work equally well for keto, bodybuilding, endurance athlete, or balanced diets.
