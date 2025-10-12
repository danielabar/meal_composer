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

## Usage Examples

WIP: Update categories now that we're using FNDDS instead of Foundational Foods

If you want more than one of the same category at a meal, just include it twice. For example, the plan below will include two vegetables for dinner.

**Strict Keto**

```ruby
meal_structure = {
  breakfast: [ "Citrus fruits", "Butter and animal fats", "Eggs and omelets" ],
  lunch: [ "Other dark green vegetables", "Chicken, whole pieces", "Salad dressings and vegetable oils" ],
  dinner: [ "Beef, excludes ground", "Butter and animal fats", "Other red and orange vegetables", "Other dark green vegetables" ]
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
Plan uses 10 foods totaling 778.0g

=== BREAKFAST ===
98.5g of Grapefruit, raw
48.2g of Table fat, NFS
91.2g of Egg omelet or scrambled egg, with cheese and meat, no added fat
Breakfast macros: carbs=12.0g, protein=14.0g, fat=48.0g

=== LUNCH ===
97.8g of Kale, NS as to form, cooked
93.5g of Chicken thigh, baked, coated, skin / coating not eaten
48.8g of Sesame oil
Lunch macros: carbs=5.0g, protein=25.0g, fat=62.0g

=== DINNER ===
75.0g of Beef, steak, strip, NS as to fat eaten
75.0g of Butter, NFS
75.0g of Winter squash, cooked, fat added
75.0g of Kale, fresh, cooked, fat added
Dinner macros: carbs=10.0g, protein=24.0g, fat=78.0g

=== DAILY TOTALS ===
Target: 25.0g carbs, 60.0g protein, 180.0g fat
Actual: 26.0g carbs, 63.0g protein, 188.0g fat
Difference: carbs 1.0g, protein 3.0g, fat 8.0g
Within tolerance: true
```

Visual from ChatGPT - needs update after switch to FNDDS

![strict keto](docs/images/strict-keto.png "strict keto")

**High Protein Athlete**

```ruby
meal_structure = {
  breakfast: ["Dairy and Egg Products", "Cereal Grains and Pasta", "Fruits and Fruit Juices", "Nut and Seed Products"],
  lunch: ["Poultry Products", "Vegetables and Vegetable Products", "Legumes and Legume Products", "Cereal Grains and Pasta"],
  dinner: ["Beef Products", "Vegetables and Vegetable Products", "Cereal Grains and Pasta", "Dairy and Egg Products", "Nut and Seed Products"]
}
macro_targets = MacroTargets.new(carbs: 250, protein: 180, fat: 70)
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
=== BREAKFAST ===
164.9g of Eggs, Grade A, Large, egg white
85.6g of Flour, whole wheat, unenriched
62.4g of Cranberry juice, not fortified, from concentrate, shelf stable
33.6g of Almond butter, creamy
Breakfast macros: carbs=77.0g, protein=38.0g, fat=20.0g

=== LUNCH ===
143.4g of Chicken, breast, meat and skin, raw
75.8g of Tomato, roma
35.3g of Peanut butter, smooth style, with salt
110.3g of Flour, whole wheat, unenriched
Lunch macros: carbs=89.0g, protein=56.0g, fat=28.0g

=== DINNER ===
233.5g of Beef, flank, steak, boneless, choice, raw
85.9g of Mushrooms, shiitake
109.3g of Oats, whole grain, rolled, old fashioned
78.8g of Milk, reduced fat, fluid, 2% milkfat, with added vitamin A and vitamin D
10.0g of Almond butter, creamy
Dinner macros: carbs=88.0g, protein=69.0g, fat=35.0g

=== DAILY TOTALS ===
Target: 250.0g carbs, 180.0g protein, 70.0g fat
Actual: 254.0g carbs, 162.0g protein, 84.0g fat
Difference: carbs 4.0g, protein -18.0g, fat 14.0g
Within tolerance: false
```

Visual from ChatGPT (assume flour === bread)

![high protein athlete](docs/images/high-protein-athlete.png "high protein athlete")

## Current Status

Early development. The algorithm successfully generates meal plans within macro tolerances but may require multiple attempts for very restrictive targets.

The meal structures can be customized wrt categories at each meal, with exactly one food per category. Future versions may include flexibility to customize the number of meals per day and the number of foods from each category within each meal.

## Reference Data

[FoodData Central Download Datasets](https://fdc.nal.usda.gov/download-datasets)
