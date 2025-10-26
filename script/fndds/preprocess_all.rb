#!/usr/bin/env ruby
#
# FNDDS Data Preprocessing Pipeline
# ==================================
#
# WHAT THIS DOES:
# Runs all FNDDS preprocessing scripts in the correct order to prepare clean CSVs
# for database seeding. This is the single entry point for all data cleanup.
#
# WHY THIS IS NEEDED:
# The FNDDS data requires multiple cleanup steps that must run in a specific order:
#   1. Category filtering (remove unsuitable categories)
#   2. Food filtering (remove foods in excluded categories + unsuitable patterns)
#   3. Food deduplication (collapse redundant variations)
#   4. Nutrient filtering (keep only nutrients for remaining foods)
#
# USAGE:
#   ruby script/fndds/preprocess_all.rb
#
# This script will:
#   - Run all preprocessing scripts in order
#   - Show progress and results for each step
#   - Stop if any step fails
#   - Generate all *_clean.csv files needed for seeding
#
# PREREQUISITES:
# Raw FNDDS CSV files must be present in db/data/fndds/:
#   - wweia_food_category.csv
#   - food.csv
#   - nutrient.csv
#   - food_nutrient.csv

require 'fileutils'

SCRIPT_DIR = __dir__
SCRIPTS = [
  {
    name: "Category Cleanup",
    script: "extract_clean_food_categories.rb",
    description: "Filters food categories to remove mixed dishes, baby foods, beverages, etc."
  },
  {
    name: "Food Cleanup",
    script: "extract_clean_foods.rb",
    description: "Removes foods in excluded categories and unsuitable patterns (restaurant, 'with', etc.)"
  },
  {
    name: "Food Deduplication",
    script: "deduplicate_foods.rb",
    description: "Collapses redundant food variations (NS as to, fried, raw vs cooked, etc.)"
  },
  {
    name: "Nutrient Cleanup",
    script: "extract_clean_food_nutrients.rb",
    description: "Keeps only nutrient records for remaining foods"
  }
]

puts "=" * 70
puts "FNDDS DATA PREPROCESSING PIPELINE"
puts "=" * 70
puts ""
puts "This will run #{SCRIPTS.size} preprocessing steps in sequence:"
SCRIPTS.each_with_index do |step, i|
  puts "  #{i + 1}. #{step[:name]}"
  puts "     #{step[:description]}"
end
puts ""
puts "=" * 70
puts ""

# Track overall results
start_time = Time.now
all_succeeded = true

SCRIPTS.each_with_index do |step, i|
  step_num = i + 1
  puts ""
  puts "━" * 70
  puts "STEP #{step_num}/#{SCRIPTS.size}: #{step[:name]}"
  puts "━" * 70
  puts ""

  script_path = File.join(SCRIPT_DIR, step[:script])

  unless File.exist?(script_path)
    puts "❌ Error: Script not found: #{script_path}"
    all_succeeded = false
    break
  end

  # Run the script
  step_start = Time.now
  success = system("ruby", script_path)
  step_duration = Time.now - step_start

  unless success
    puts ""
    puts "❌ Step #{step_num} failed!"
    puts "Script: #{step[:script]}"
    all_succeeded = false
    break
  end

  puts ""
  puts "✅ Step #{step_num} completed in #{step_duration.round(1)}s"
end

# Final summary
total_duration = Time.now - start_time

puts ""
puts "=" * 70
if all_succeeded
  puts "✅ ALL PREPROCESSING COMPLETE!"
  puts "=" * 70
  puts ""
  puts "Total time: #{total_duration.round(1)}s"
  puts ""
  puts "Generated clean CSV files in db/data/fndds/:"
  puts "  - wweia_food_category_clean.csv"
  puts "  - food_clean.csv"
  puts "  - food_deduplicated.csv"
  puts "  - food_nutrient_clean.csv"
  puts ""
  puts "Next step:"
  puts "  bin/rails db:seed"
  puts ""
else
  puts "❌ PREPROCESSING FAILED"
  puts "=" * 70
  puts ""
  puts "Please fix the errors above and try again."
  puts ""
  exit 1
end
