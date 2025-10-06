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

**With default meal structure**

```ruby
macro_targets = MacroTargets.new(carbs: 25, protein: 60, fat: 180)
result = ThreeIngredientComposer.new.compose_daily_meals(macro_targets: macro_targets)

if result.composed?
  puts result.daily_plan.pretty_print
else
  puts "Failed: #{result.error}"
end
```

Sample output:
```
=== BREAKFAST ===
127.5g of Cottage cheese, full fat, large or small curd
58.5g of Oil, safflower
17.9g of Kiwifruit (kiwi), green, peeled, raw
Breakfast macros: carbs=8.3g, protein=15.0g, fat=60.0g

=== LUNCH ===
109.6g of Chicken, thigh, meat and skin, raw
48.4g of Oil, sunflower
130.5g of Cabbage, green, raw
Lunch macros: carbs=8.3g, protein=20.0g, fat=60.0g

=== DINNER ===
63.0g of Beef, round, top round roast, boneless, separable lean only, trimmed to 0" fat, select, raw
61.8g of Oil, corn
144.6g of Mushroom, pioppini
Dinner macros: carbs=8.3g, protein=20.0g, fat=60.0g

=== DAILY TOTALS ===
Target: 25.0g carbs, 60.0g protein, 180.0g fat
Actual: 24.999999999999993g carbs, 54.999999999999986g protein, 180.0g fat
Difference: carbs 0.0g, protein -5.0g, fat 0.0g
Within tolerance: true
```

**With custom meal structure**

```ruby
meal_structure = {
  breakfast: [ "Dairy and Egg Products", "Fats and Oils", "Vegetables and Vegetable Products" ],
  lunch: [ "Finfish and Shellfish Products", "Fats and Oils", "Vegetables and Vegetable Products" ],
  dinner: [ "Beef Products", "Fats and Oils", "Cereal Grains and Pasta" ]
}
macro_targets = MacroTargets.new(carbs: 100, protein: 150, fat: 95)
result = ThreeIngredientComposer.new.compose_daily_meals(macro_targets: macro_targets, meal_structure: meal_structure)
if result.composed?
  puts result.daily_plan.pretty_print
else
  puts "Failed: #{result.error}"
end
```

Sample output:
```
=== BREAKFAST ===
55.5g of Egg, white, dried
28.3g of Oil, coconut
202.6g of Corn, sweet, yellow and white kernels,  fresh, raw
Breakfast macros: carbs=33.3g, protein=50.0g, fat=31.7g

=== LUNCH ===
256.1g of Fish, cod, Atlantic, wild caught, raw
30.6g of Oil, corn
449.7g of Beans, snap, green, raw
Lunch macros: carbs=33.3g, protein=50.0g, fat=31.7g

=== DINNER ===
188.1g of Beef, round, eye of round roast, boneless, separable lean only, trimmed to 0" fat, select, raw
25.8g of Oil, corn
47.8g of Oats, whole grain, steel cut
Dinner macros: carbs=33.3g, protein=50.0g, fat=31.7g

=== DAILY TOTALS ===
Target: 100.0g carbs, 150.0g protein, 95.0g fat
Actual: 99.99999999999999g carbs, 149.99999999999997g protein, 94.99999999999997g fat
Difference: carbs 0.0g, protein 0.0g, fat 0.0g
Within tolerance: true
```

## Current Status

Early development. The algorithm successfully generates meal plans within macro tolerances but may require multiple attempts for very restrictive targets.

The meal structures can be customized wrt categories at each meal, but are limited to exactly three categories per meal. Future versions may include flexibility to customize the number of meals per day and the number of foods from each category within each meal.
