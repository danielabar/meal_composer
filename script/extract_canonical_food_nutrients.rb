#!/usr/bin/env ruby

require 'csv'

# Paths
INPUT_NUTRIENT_CSV   = 'db/data/food_nutrient.csv'
CANONICAL_FOOD_CSV   = 'db/data/food_canonical.csv'
OUTPUT_NUTRIENT_CSV  = 'db/data/food_nutrient_canonical.csv'

# Load canonical food IDs
puts "Loading canonical foods from #{CANONICAL_FOOD_CSV}..."
canonical_ids = CSV.read(CANONICAL_FOOD_CSV, headers: true).map { |row| row['fdc_id'] }.to_set
puts "Found #{canonical_ids.size} canonical foods."

# Read nutrient CSV and filter
puts "Processing #{INPUT_NUTRIENT_CSV}..."
rows = CSV.read(INPUT_NUTRIENT_CSV, headers: true)
canonical_nutrients = rows.select { |row| canonical_ids.include?(row['fdc_id']) }

# Write filtered CSV
CSV.open(OUTPUT_NUTRIENT_CSV, 'w', write_headers: true, headers: rows.headers) do |csv|
  canonical_nutrients.each { |row| csv << row }
end

puts "Done! #{canonical_nutrients.size} nutrient records written to #{OUTPUT_NUTRIENT_CSV}"
