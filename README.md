# Meal Composer

A Rails application that generates meal plans based on target macro-nutrient goals.

## Problem

People following specific diets (keto, low-carb, bodybuilding, etc.) need to hit precise macro-nutrient targets daily. Manually planning meals to achieve exact gram targets for carbohydrates, protein, and fat is time-consuming and often results in repetitive, boring meal plans.

## Solution

This app generates ingredient-based meal plans by:

- Taking user-specified macro targets (e.g., 50g carbs, 100g protein, 150g fat)
- Selecting foods from a comprehensive USDA nutrition database
- Ensuring meal variety by requiring specific food categories per meal, currently fixed at:
  - **Breakfast**: Dairy/eggs + cooking fats + fruits
  - **Lunch**: Poultry + cooking fats + vegetables
  - **Dinner**: Beef + cooking fats + vegetables
- Calculating precise portions to meet daily macro targets within tolerance
- Providing realistic, cookable meals (no raw meat without cooking fats)

**Note**: This app provides ingredient quantities per meal, not recipes. For example, the output tells you how much chicken, broccoli, and olive oil you need for lunch, but not how to prepare them. This approach is ideal for people who want macro-precise meal planning without complexity. You avoid detailed cooking instructions, long ingredient lists, and exotic spices or sauces you may not have on hand.

The app uses a constrained optimization algorithm that balances nutritional accuracy with meal palatability and variety.

## Requirements

- Docker and Docker Compose
- Ruby (version specified in `.ruby-version`)
- PostgreSQL client (version matching `docker-compose.yml`)

## Setup

1. **Start the database**:
   ```bash
   docker-compose up
   ```

2. **First-time setup** (in another terminal):
   ```bash
   bin/setup
   ```

3. **Start the development server**:
   ```bash
   bin/dev
   ```

The setup process will install dependencies, create the database, and load USDA nutrition data.

## Usage

```ruby
macro_targets = MacroTargets.new(carbs: 50, protein: 100, fat: 150)
composer = DailyMealComposer.new
result = composer.compose_daily_meals(macro_targets: macro_targets)

if result.composed?
  plan = result.daily_plan
  puts "Success! Plan uses #{plan.total_foods} foods totaling #{plan.total_grams}g"
  puts "Target: #{plan.target_macros}"
  puts "Actual: #{plan.actual_macros}"
  puts "Within tolerance: #{plan.within_tolerance?}"

  puts "=== BREAKFAST ==="
  plan.breakfast.food_portions.each do |portion|
    puts "#{portion.grams.round(1)}g of #{portion.food.description}"
  end
  puts "Breakfast macros: carbs=#{plan.breakfast.macros.carbs.round(1)}g, protein=#{plan.breakfast.macros.protein.round(1)}g, fat=#{plan.breakfast.macros.fat.round(1)}g"
  puts

  puts "=== LUNCH ==="
  plan.lunch.food_portions.each do |portion|
    puts "#{portion.grams.round(1)}g of #{portion.food.description}"
  end
  puts "Lunch macros: carbs=#{plan.lunch.macros.carbs.round(1)}g, protein=#{plan.lunch.macros.protein.round(1)}g, fat=#{plan.lunch.macros.fat.round(1)}g"
  puts

  puts "=== DINNER ==="
  plan.dinner.food_portions.each do |portion|
    puts "#{portion.grams.round(1)}g of #{portion.food.description}"
  end
  puts "Dinner macros: carbs=#{plan.dinner.macros.carbs.round(1)}g, protein=#{plan.dinner.macros.protein.round(1)}g, fat=#{plan.dinner.macros.fat.round(1)}g"
  puts

  puts "=== DAILY TOTALS ==="
  puts "Target: #{plan.target_macros}"
  puts "Actual: #{plan.actual_macros}"
  puts "Difference: carbs #{(plan.actual_macros.carbs - plan.target_macros.carbs).round(1)}g, protein #{(plan.actual_macros.protein - plan.target_macros.protein).round(1)}g, fat #{(plan.actual_macros.fat - plan.target_macros.fat).round(1)}g"
  puts "Within tolerance: #{plan.within_tolerance?}"
else
  puts "Failed: #{result.error}"
end
```

Sample output:
```
Success! Plan uses 9 foods totaling 574.8133198789102g
Target: 50.0g carbs, 100.0g protein, 150.0g fat
Actual: 33.96055188698285g carbs, 66.117g protein, 141.5068g fat
Within tolerance: false
=== BREAKFAST ===
80.0g of Cheese, cheddar
20.7g of Oil, coconut
80.0g of Kiwifruit (kiwi), green, peeled, raw
Breakfast macros: carbs=13.2g, protein=19.4g, fat=48.2g

=== LUNCH ===
80.0g of Turkey, ground, 93% lean, 7% fat, pan-broiled crumbles
37.0g of Oil, coconut
80.0g of Squash, winter, butternut, raw
Lunch macros: carbs=8.7g, protein=22.6g, fat=46.1g

=== DINNER ===
80.0g of Beef, short loin, t-bone steak, bone-in, separable lean only, trimmed to 1/8" fat, choice, cooked, grilled
37.1g of Oil, coconut
80.0g of Corn, sweet, yellow and white kernels,  fresh, raw
Dinner macros: carbs=12.1g, protein=24.1g, fat=47.2g

=== DAILY TOTALS ===
Target: 50.0g carbs, 100.0g protein, 150.0g fat
Actual: 33.96055188698285g carbs, 66.117g protein, 141.5068g fat
Difference: carbs -16.0g, protein -33.9g, fat -8.5g
Within tolerance: false
```

## Current Status

Early development. The algorithm successfully generates meal plans within macro tolerances but may require multiple attempts for very restrictive targets.

The meal structures are currently fixed (one dairy/egg + one fat + one fruit for breakfast, etc.). Future versions may include flexibility to customize the number of meals per day and the number of foods from each category within each meal.
