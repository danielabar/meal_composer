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

Strict Keto

```ruby
meal_structure = {
  breakfast: [ "Dairy and Egg Products", "Fats and Oils", "Vegetables and Vegetable Products" ],
  lunch: [ "Finfish and Shellfish Products", "Fats and Oils", "Vegetables and Vegetable Products" ],
  dinner: [ "Beef Products", "Fats and Oils", "Vegetables and Vegetable Products" ]
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

Sample output:

```
Plan uses 9 foods totaling 757.0g

=== BREAKFAST ===
77.1g of Cheese, cotija, solid
29.5g of Oil, sunflower
99.8g of Squash, summer, green, zucchini, includes skin, raw
Breakfast macros: carbs=5.0g, protein=19.0g, fat=49.0g

=== LUNCH ===
116.3g of Fish, pollock, raw
67.0g of Oil, olive, extra light
104.9g of Squash, summer, green, zucchini, includes skin, raw
Lunch macros: carbs=3.0g, protein=15.0g, fat=63.0g

=== DINNER ===
94.9g of Beef, short loin, t-bone steak, bone-in, separable lean only, trimmed to 1/8" fat, choice, cooked, grilled
67.8g of Oil, canola
99.7g of Squash, winter, acorn, raw
Dinner macros: carbs=10.0g, protein=27.0g, fat=75.0g

=== DAILY TOTALS ===
Target: 25.0g carbs, 60.0g protein, 180.0g fat
Actual: 19.0g carbs, 62.0g protein, 187.0g fat
Difference: carbs -6.0g, protein 2.0g, fat 7.0g
Within tolerance: true
```

## Current Status

Early development. The algorithm successfully generates meal plans within macro tolerances but may require multiple attempts for very restrictive targets.

The meal structures can be customized wrt categories at each meal, with exactly one food per category. Future versions may include flexibility to customize the number of meals per day and the number of foods from each category within each meal.

## Reference Data

[FoodData Central Download Datasets](https://fdc.nal.usda.gov/download-datasets)
