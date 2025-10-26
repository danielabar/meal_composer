#!/usr/bin/env ruby
#
# FNDDS Food Category CSV Preprocessor
# =====================================
#
# WHAT THIS DOES:
# Filters the raw FNDDS wweia_food_category.csv to create a "clean" version containing
# only food categories suitable for whole-foods meal planning.
#
# WHY THIS IS NEEDED:
# The USDA FNDDS contains 173 food categories, but many are unsuitable for a meal
# planning app focused on whole foods that users cook at home:
#   - Baby/infant foods (formula, baby food, etc.)
#   - Mixed dishes (pizza, burritos, sandwiches, casseroles)
#   - Processed sweets and snacks (candy, cookies, chips)
#   - Beverages (juices, sodas, alcohol - users drink water separately)
#   - Condiments and sweeteners (these aren't meal components)
#
# APPROACH:
# Category-level exclusion is the first tier of cleanup. By removing unsuitable
# categories here, we automatically exclude all foods within those categories,
# which is much more efficient than food-by-food filtering.
#
# USAGE:
#   ruby script/fndds/extract_clean_food_categories.rb
#
# INPUT:  db/data/fndds/wweia_food_category.csv           (raw USDA data)
# OUTPUT: db/data/fndds/wweia_food_category_clean.csv     (filtered for meal planning)
#
# After running this, update db/seeds/fndds/food_categories.rb to load the _clean.csv

require 'csv'

# File paths
INPUT_CSV  = File.expand_path('../../db/data/fndds/wweia_food_category.csv', __dir__)
OUTPUT_CSV = File.expand_path('../../db/data/fndds/wweia_food_category_clean.csv', __dir__)

# EXCLUDED CATEGORIES
# These category codes will be filtered out because they contain foods
# unsuitable for whole-foods meal planning
EXCLUDED_CATEGORY_CODES = [
  # Baby/infant foods (9000 series)
  "9002",  # Baby food: cereals
  "9004",  # Baby food: fruit
  "9006",  # Baby food: vegetables
  "9007",  # Baby food: mixtures
  "9008",  # Baby food: meat and dinners
  "9010",  # Baby food: yogurt
  "9012",  # Baby food: snacks and sweets
  "9202",  # Baby juice
  "9204",  # Baby water
  "9402",  # Formula, ready-to-feed
  "9404",  # Formula, prepared from powder
  "9602",  # Human milk
  "9802",  # Protein and nutritional powders

  # Mixed dishes (3000 series) - composite foods, not single ingredients
  "3002",  # Meat mixed dishes
  "3004",  # Poultry mixed dishes
  "3006",  # Seafood mixed dishes
  "3102",  # Bean, pea, legume dishes
  "3104",  # Vegetable dishes
  "3202",  # Rice mixed dishes
  "3204",  # Pasta mixed dishes, excludes macaroni and cheese
  "3206",  # Macaroni and cheese
  "3208",  # Turnovers and other grain-based items
  "3402",  # Fried rice and lo/chow mein
  "3404",  # Stir-fry and soy-based sauce mixtures
  "3406",  # Egg rolls, dumplings, sushi
  "3502",  # Burritos and tacos
  "3504",  # Nachos
  "3506",  # Other Mexican mixed dishes
  "3602",  # Pizza
  "3702",  # Burgers
  "3703",  # Frankfurter sandwiches
  "3704",  # Chicken fillet sandwiches
  "3706",  # Egg/breakfast sandwiches
  "3720",  # Cheese sandwiches
  "3722",  # Peanut butter and jelly sandwiches
  "3730",  # Seafood sandwiches
  "3740",  # Deli and cured meat sandwiches
  "3742",  # Meat and BBQ sandwiches
  "3744",  # Vegetable sandwiches/burgers
  "3804",  # Soups, broth-based
  "3806",  # Soups, cream-based
  "3808",  # Ramen and Asian broth-based soups

  # Sweets and desserts (5500-5800 series)
  "5502",  # Cakes and pies
  "5504",  # Cookies and brownies
  "5506",  # Doughnuts, sweet rolls, pastries
  "5702",  # Candy containing chocolate
  "5704",  # Candy not containing chocolate
  "5802",  # Ice cream and frozen dairy desserts
  "5804",  # Pudding
  "5806",  # Gelatins, ices, sorbets

  # Snack foods (5000-5400 series)
  "5002",  # Potato chips
  "5004",  # Tortilla, corn, other chips
  "5006",  # Popcorn
  "5008",  # Pretzels/snack mix
  "5202",  # Crackers, excludes saltines
  "5204",  # Saltine crackers
  "5402",  # Cereal bars
  "5404",  # Nutrition bars

  # Ready-to-eat cereals (too processed for whole-foods approach)
  "4602",  # Ready-to-eat cereal, higher sugar (>21.2g/100g)
  "4604",  # Ready-to-eat cereal, lower sugar (=<21.2g/100g)

  # Beverages (7000 series) - users manage hydration separately
  "7002",  # Citrus juice
  "7004",  # Apple juice
  "7006",  # Other fruit juice
  "7008",  # Vegetable juice
  "7102",  # Diet soft drinks
  "7104",  # Diet sport and energy drinks
  "7106",  # Other diet drinks
  "7202",  # Soft drinks
  "7204",  # Fruit drinks
  "7206",  # Sport and energy drinks
  "7208",  # Nutritional beverages
  "7220",  # Smoothies and grain drinks
  "7302",  # Coffee
  "7304",  # Tea
  "7502",  # Beer
  "7504",  # Wine
  "7506",  # Liquor and cocktails
  "7702",  # Tap water
  "7704",  # Bottled water
  "7802",  # Flavored or carbonated water
  "7804",  # Enhanced water

  # Milk-based beverages (not plain milk)
  "1202",  # Flavored milk, whole
  "1204",  # Flavored milk, reduced fat
  "1206",  # Flavored milk, lowfat
  "1208",  # Flavored milk, nonfat
  "1402",  # Milk shakes and other dairy drinks

  # Condiments, sauces, sweeteners (8400-8800 series)
  # Note: We KEEP 8002 (butter/fats) and 8012 (oils) as cooking fats
  "8402",  # Tomato-based condiments
  "8404",  # Soy-based condiments
  "8406",  # Mustard and other condiments
  "8408",  # Olives, pickles, pickled vegetables
  "8410",  # Pasta sauces, tomato-based
  "8412",  # Dips, gravies, other sauces
  "8802",  # Sugars and honey
  "8804",  # Sugar substitutes
  "8806",  # Jams, syrups, toppings

  # Fried vegetables (not a cooking method we want to encourage)
  "6430",  # Fried vegetables

  # Special preparation vegetables (users will prepare their own)
  "6432",  # Coleslaw, non-lettuce salads
  "6489",  # Vegetables on a sandwich

  # Miscellaneous
  "9999"   # Not included in a food category
]

# Process the CSV
puts "FNDDS Food Category Preprocessor"
puts "=" * 60
puts "Input:  #{INPUT_CSV}"
puts "Output: #{OUTPUT_CSV}"
puts ""

unless File.exist?(INPUT_CSV)
  puts "❌ Error: Input file not found: #{INPUT_CSV}"
  exit 1
end

puts "Reading CSV..."
rows = CSV.read(INPUT_CSV, headers: true)
puts "  Total categories in raw FNDDS: #{rows.size}"

# Filter out excluded categories
puts "\nApplying category exclusion filter..."
clean_rows = rows.reject do |row|
  category_code = row['wweia_food_category']
  EXCLUDED_CATEGORY_CODES.include?(category_code)
end

# Write filtered CSV
puts "\nWriting clean CSV..."
CSV.open(OUTPUT_CSV, 'w', write_headers: true, headers: rows.headers) do |csv|
  clean_rows.each { |row| csv << row }
end

# Summary
excluded_count = rows.size - clean_rows.size
exclusion_pct = (excluded_count.to_f / rows.size * 100).round(1)

puts ""
puts "=" * 60
puts "✅ Processing complete!"
puts ""
puts "Results:"
puts "  Clean categories:    #{clean_rows.size}"
puts "  Excluded categories: #{excluded_count} (#{exclusion_pct}%)"
puts ""
puts "Excluded category types:"
puts "  - Baby/infant foods"
puts "  - Mixed dishes (pizza, burritos, sandwiches, soups)"
puts "  - Sweets and desserts"
puts "  - Snack foods and processed cereals"
puts "  - Beverages (kept: plain milk only)"
puts "  - Condiments and sweeteners (kept: butter/fats, oils)"
puts "  - Fried/prepared vegetables"
puts ""
puts "Next steps:"
puts "  1. Update db/seeds/fndds/food_categories.rb to load wweia_food_category_clean.csv"
puts "  2. Re-run extract_clean_foods.rb (it will skip foods with excluded categories)"
puts "  3. Re-run extract_clean_food_nutrients.rb to update nutrient data"
puts ""
