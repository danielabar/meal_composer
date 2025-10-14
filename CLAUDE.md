# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Meal Composer is a Rails 8 application that generates macro-precise meal plans using constrained optimization. It takes user-specified macronutrient targets (carbs, protein, fat) and generates daily meal plans with specific ingredient quantities from the USDA nutrition database.

Key differentiator: This app outputs ingredient quantities, not recipes. Users get precise amounts of foods needed to hit macro targets, without complicated cooking instructions.

## Development Commands

### Setup
```bash
docker-compose up              # Start PostgreSQL database
bin/setup                      # First-time setup: installs gems, creates DB, loads data
bin/dev                        # Start development server with Procfile.dev
```

### Testing
```bash
bin/rspec                      # Run all tests
bin/rspec spec/path/to/file_spec.rb  # Run a single test file
```

### Linting
```bash
bin/rubocop                    # Run RuboCop linter
bin/rubocop -a                 # Auto-correct violations
bin/brakeman                   # Security scanner
```

### Database
```bash
bin/rails db:prepare           # Setup/update database
DATASET=fndds bin/rails db:seed    # Load FNDDS nutrition data (default)
DATASET=foundation bin/rails db:seed  # Load Foundation Foods data (legacy)
```

The app uses FNDDS (Food and Nutrient Database for Dietary Studies) as the primary dataset. Foundation Foods is the older dataset still supported for backward compatibility.

### Rails Console
```bash
bin/rails console              # Interactive console for testing code
```

## Architecture

### Core Algorithm: FlexibleMealComposer

The heart of the application is `FlexibleMealComposer` (app/services/flexible_meal_composer.rb), which uses gradient descent optimization to solve an underdetermined system of equations for meal composition.

**Mathematical Model**: For a meal with n ingredients, solve:
- c₁p₁ + c₂p₂ + ... + cₙpₙ = target_carbs
- p₁p₁ + p₂p₂ + ... + pₙpₙ = target_protein
- f₁p₁ + f₂p₂ + ... + fₙpₙ = target_fat

Where cᵢ, pᵢ, fᵢ are macro coefficients per gram and pᵢ are portion sizes to solve for.

**Key constants** (in FlexibleMealComposer):
- `MACRO_TOLERANCE_GRAMS = 8.0` - Acceptable deviation from targets
- `MIN_PORTION_SIZE = 10.0` - Minimum grams per food
- `MAX_PORTION_SIZE = 500.0` - Maximum grams per food
- `MAX_ITERATIONS = 200` - Gradient descent iteration limit
- `LEARNING_RATE = 0.5` - Optimization step size

**Meal composition flow**:
1. `compose_daily_meals` - Entry point, distributes daily macros across 3 meals
2. `compose_single_meal` - Selects foods and optimizes portions per meal (up to 10 attempts)
3. `optimize_portions_iterative` - Gradient descent to find portion sizes meeting targets
4. Returns `Result` with `DailyMealPlan` containing 3 `Meal` objects

### Data Models

**Core Models**:
- `Food` - USDA food items (fdc_id, description, food_category_id)
- `FoodCategory` - FNDDS food categories (e.g., "Beef, excludes ground")
- `Nutrient` - Nutritional components (name, unit_name, nutrient_nbr)
- `FoodNutrient` - Join table storing nutrient amounts per 100g of food
- `User` - Authentication (uses Rails 8 authentication generator)
- `DailyMacroTarget` - User's macro goals (belongs_to :user)

**Value Objects** (Plain Ruby Classes):
- `MacroTargets` - Stores carbs/protein/fat values
- `DailyMealPlan` - Contains 3 meals + target/actual macros
- `Meal` - Contains food_portions array + calculated macros
- `FoodPortion` - Food + grams amount

### Services

**NutrientLookupService** (app/services/nutrient_lookup_service.rb):
- Extracts macro data from the complex USDA nutrient database
- Handles multiple nutrient naming conventions across datasets
- Returns hash with `:carbohydrates`, `:protein`, `:fat` keys (values in grams per 100g)

**ThreeIngredientComposer** (app/services/three_ingredient_composer.rb):
- Legacy service for 3-ingredient meals using exact linear algebra
- Uses Cramer's rule to solve the system deterministically
- Still present but FlexibleMealComposer is preferred for flexibility

### Database Seeding

Seeds are complex due to USDA data size and format. Key files:

**db/seeds.rb** - Entry point, loads either `seeds_fndds.rb` or `seeds_foundation.rb` based on DATASET env var

**db/seeds/fndds/** - FNDDS dataset loaders:
- `food_categories.rb`, `foods.rb`, `nutrients.rb`, `food_nutrients.rb` - Load USDA CSVs
- `cleanup*.rb` files - Remove unwanted foods (baby foods, restaurant items, composite foods)

The cleanup step is important: it removes ~30% of FNDDS foods that aren't suitable for meal planning (e.g., "Chicken nuggets, fast food" or "Gerber baby formula").

### Controllers & Views

Standard Rails 8 setup with:
- Hotwire (Turbo + Stimulus) for frontend interactivity
- Tailwind CSS for styling
- Session-based authentication (bcrypt, no Devise)

**Key controllers**:
- `DashboardController` - Main authenticated user landing
- `DailyMacroTargetsController` - CRUD for user macro goals
- `SessionsController`, `PasswordsController` - Authentication

## Testing

Uses RSpec with:
- FactoryBot for test data (see spec/factories/)
- Shoulda Matchers for ActiveRecord validations
- Capybara for system tests

**Important**: Most models require database data to function (foods, nutrients, categories). Many specs likely depend on seeds or factories creating complete object graphs.

## Important Implementation Notes

1. **Category names changed**: The app recently migrated from Foundation Foods to FNDDS. Food category names are different. The `DEFAULT_MEAL_STRUCTURE` in FlexibleMealComposer has a TODO noting it needs updating to FNDDS categories.

2. **Macro lookup complexity**: Not all foods have all macros. `NutrientLookupService` handles multiple naming conventions. `FlexibleMealComposer#food_has_complete_macro_data?` includes special logic for oils (they only need fat data).

3. **Optimization can fail**: `compose_single_meal` tries 10 times with random food selections. If standard constraints fail, it relaxes tolerance. This is expected behavior for very restrictive macro targets.

4. **Meal structure is customizable**: Users can specify which food categories appear in each meal. The structure determines variety and realism (e.g., including cooking fats prevents raw meat suggestions).

5. **Macro distribution**: Daily targets are split across meals using fixed percentages (breakfast: 30/25/25, lunch: 35/35/35, dinner: 35/40/40 for carbs/protein/fat).

## Console Testing Example

```ruby
meal_structure = {
  breakfast: [ "Eggs and omelets", "Butter and animal fats", "Blueberries and other berries" ],
  lunch: [ "Chicken, whole pieces", "Other dark green vegetables", "Salad dressings and vegetable oils" ],
  dinner: [ "Beef, excludes ground", "Other vegetables and combinations", "Butter and animal fats" ]
}

macro_targets = MacroTargets.new(carbs: 25, protein: 60, fat: 180)

result = FlexibleMealComposer.new.compose_daily_meals(
  macro_targets: macro_targets,
  meal_structure: meal_structure
)

if result.composed?
  puts result.daily_plan.pretty_print
else
  puts "Failed: #{result.error}"
end
```

## Docker

Dockerfile and docker-compose.yml are configured for deployment with Kamal. PostgreSQL runs in Docker during development. Database connection settings are in config/database.yml (uses DATABASE_URL or falls back to localhost:5432).
