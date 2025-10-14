#!/usr/bin/env ruby
#
# FNDDS Food CSV Preprocessor
# ============================
#
# WHAT THIS DOES:
# Filters the raw FNDDS food.csv to create a "clean" version containing only foods
# suitable for general meal planning purposes.
#
# WHY THIS IS NEEDED:
# The USDA FNDDS (Food and Nutrient Database for Dietary Studies) contains ~8,000 foods,
# but approximately 30% are unsuitable for a meal planning app:
#   - Baby/infant foods (formula, baby food, toddler meals)
#   - Overly specific composite foods ("Chicken with pasta and vegetables")
#   - Fast food and restaurant items (highly variable, brand-specific)
#   - Imitation/mock foods (processed substitutes with inconsistent nutrition)
#
# PROBLEM WITH POST-LOAD CLEANUP:
# The original approach loaded ALL foods into PostgreSQL, then ran 4 separate cleanup
# scripts that used ActiveRecord's `destroy_all` to delete unwanted records.
# With ~2,500 foods to remove (many with 240+ nutrient records each), this meant:
#   - 353,017 food_nutrient inserts → delete ~100,000 of them
#   - ~690,000 SQL queries just for the composite_foods cleanup alone
#   - 30+ minutes of unnecessary database operations
#   - Index building for data that gets immediately deleted
#
# BENEFITS OF CSV PREPROCESSING:
#   1. Filter once, use forever - clean CSVs can be committed to version control
#   2. 10x faster seeds - only insert ~5,500 foods instead of ~8,000
#   3. ~250,000 nutrient records instead of ~353,000 (saving ~15 minutes on bulk insert)
#   4. No cleanup phase needed - seeds become simple "load clean CSVs"
#   5. Reproducible - anyone running seeds gets identical filtered data
#   6. Auditable - can review exclusion patterns in code, not SQL logs
#
# USAGE:
#   ruby script/fndds/extract_clean_foods.rb
#
# INPUT:  db/data/fndds/food.csv           (raw USDA data)
# OUTPUT: db/data/fndds/food_clean.csv     (filtered for meal planning)
#
# This script replaces these post-load cleanup scripts:
#   - db/seeds/fndds/cleanup_baby_foods.rb
#   - db/seeds/fndds/cleanup_composite_foods.rb
#   - db/seeds/fndds/cleanup_restaurant_foods.rb
#   - db/seeds/fndds/cleanup_fake_foods.rb

require 'csv'

# File paths
INPUT_CSV  = File.expand_path('../../db/data/fndds/food.csv', __dir__)
OUTPUT_CSV = File.expand_path('../../db/data/fndds/food_clean.csv', __dir__)

# Exclusion patterns consolidated from all 4 cleanup scripts
EXCLUDE_PATTERNS = [
  # Baby/infant foods (from cleanup_baby_foods.rb)
  # Examples: "Milk, human", "Infant formula, ready-to-feed", "Baby food, carrots"
  /\b(infant|baby|toddler|human milk)\b/i,

  # Composite foods (from cleanup_composite_foods.rb) - 1,433 records!
  # Examples: "Chicken with pasta and vegetables", "Beef with gravy and potatoes"
  # These are too specific for general meal planning - users want individual ingredients
  /\bwith\b/i,

  # Restaurant/fast food (from cleanup_restaurant_foods.rb)
  # Examples: "Fast food, hamburger", "Restaurant, pasta dish"
  # Nutrition varies by chain/preparation, not suitable for home meal planning
  /\b(fast food|restaurant)\b/i,

  # Imitation/mock foods (from cleanup_fake_foods.rb)
  # Examples: "Imitation cheese", "Mock chicken"
  # Processed substitutes with highly variable nutritional profiles
  /\b(imitation|mock)\b/i
]

# Process the CSV
puts "FNDDS Food Preprocessor"
puts "=" * 50
puts "Input:  #{INPUT_CSV}"
puts "Output: #{OUTPUT_CSV}"
puts ""

unless File.exist?(INPUT_CSV)
  puts "❌ Error: Input file not found: #{INPUT_CSV}"
  exit 1
end

puts "Reading CSV..."
rows = CSV.read(INPUT_CSV, headers: true)
puts "  Total foods in raw FNDDS: #{rows.size}"

# Filter out unwanted foods
puts "\nApplying exclusion filters..."
clean_rows = rows.reject do |row|
  description = row['description'].to_s
  EXCLUDE_PATTERNS.any? { |pattern| description.match?(pattern) }
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
puts "=" * 50
puts "✅ Processing complete!"
puts ""
puts "Results:"
puts "  Clean foods:    #{clean_rows.size}"
puts "  Excluded foods: #{excluded_count} (#{exclusion_pct}%)"
puts ""
puts "Next steps:"
puts "  1. Run: ruby script/fndds/extract_clean_food_nutrients.rb"
puts "  2. Update db/seeds/fndds/foods.rb to load food_clean.csv"
puts "  3. Remove cleanup_*.rb scripts (no longer needed)"
