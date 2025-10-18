# FlexibleMealComposer - Core Meal Planning Algorithm

This is the heart of the meal planning application. It uses gradient descent optimization to solve an underdetermined system of equations for generating macro-precise meal plans.

## Key Concepts

The Math Problem:
- For n ingredients, solve: c₁p₁ + c₂p₂ + ... + cₙpₙ = target_carbs (and similar for protein/fat)
- When n > 3, there are infinite solutions
- Uses gradient descent to find a practical solution that fits portion constraints (10-500g per food)

Input/Output Architecture:
- Inputs: Plain Ruby data structures
  - MacroTargets PORO (carbs, protein, fat)
  - Meal structure as a hash: { breakfast: ["Category1", "Category2"], lunch: [...], dinner: [...] }
- Output: Plain Ruby objects (no ActiveRecord)
  - Result wrapper (composed? boolean, daily_plan or error)
  - PocDailyMealPlan PORO containing 3 PocMeal objects + target/actual macros
  - PocMeal PORO containing array of PocFoodPortion + calculated macros
  - PocFoodPortion PORO containing a Food AR model + grams amount

## Algorithm Flow

1. compose_daily_meals (entry point)
  - Converts meal structure category names to IDs
  - Distributes daily macros across 3 meals (breakfast: 30/25/25%, lunch: 35/35/35%, dinner: 35/40/40%)
  - Calls compose_single_meal for each meal type
  - Returns Result with PocDailyMealPlan
2. compose_single_meal (per-meal composition)
  - Tries up to 10 times with random food selections
  - After 5 failed attempts, relaxes tolerance (8g → 16g)
  - Last resort: tries once more with 4x tolerance (32g)
  - Returns PocMeal object or nil
3. optimize_portions_iterative (gradient descent)
  - Extracts macro coefficients from foods (per 100g basis)
  - Initializes portions at equal weights (300g total / n foods)
  - Iterates up to 200 times adjusting portions via gradient
  - Constrains portions to 10-500g range
  - Early stops when within tolerance (√(Σ errors²) < 8g)

## Key Constants (app/services/flexible_meal_composer.rb)

- MACRO_TOLERANCE_GRAMS = 8.0 - Acceptable deviation per macro
- MIN_PORTION_SIZE = 10.0 - Minimum grams per food
- MAX_PORTION_SIZE = 500.0 - Maximum grams per food
- MAX_ITERATIONS = 200 - Gradient descent limit
- LEARNING_RATE = 0.5 - Optimization step size

## Smart Features

Food Selection (randomly_select_foods_from_categories):
- Pre-filters foods to find those with complete macro data (app/services/flexible_meal_composer.rb:227-265)
- Makes up to 10 attempts to find suitable foods from each category
- Special handling for oils/fats (only require fat data, not carbs/protein)
- Falls back to incomplete data as last resort

Relaxation Strategy:
- Standard: 8g tolerance
- Relaxed (after 5 attempts): 16g tolerance
- Very relaxed (last resort): 32g tolerance
- Ensures meal composition succeeds even with restrictive targets

ActiveRecord Usage:
- Only uses AR models for data lookup: Food, FoodCategory, FoodNutrient
- Relies on NutrientLookupService to extract macro data
- All composition logic works with plain Ruby objects

## Design Philosophy

This was built before any user models or UI existed - purely to validate the concept of ingredient/gram/macro-based meal planning. That's why:
- Inputs are flexible data structures (hashes, arrays) not tied to AR models
- Outputs are POROs that can be easily displayed or serialized
- No assumptions about persistence or user ownership
- Focuses solely on solving the optimization problem

The architecture makes it easy to later wrap this with User-owned ActiveRecord models (like MealPlan, MealStructure, etc.) while keeping the core algorithm clean and testable.
