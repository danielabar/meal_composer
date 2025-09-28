#!/usr/bin/env ruby
# Extract portions for canonical foods

require 'csv'
require 'set'

# Paths
INPUT_PORTION_CSV   = 'db/data/food_portion.csv'
CANONICAL_FOOD_CSV  = 'db/data/food_canonical.csv'
OUTPUT_PORTION_CSV  = 'db/data/food_portion_canonical.csv'

# Load canonical food IDs
puts "Loading canonical foods from #{CANONICAL_FOOD_CSV}..."
canonical_ids = CSV.read(CANONICAL_FOOD_CSV, headers: true).map { |row| row['fdc_id'] }.to_set
puts "Found #{canonical_ids.size} canonical foods."

# Read portion CSV and filter
puts "Processing #{INPUT_PORTION_CSV}..."
rows = CSV.read(INPUT_PORTION_CSV, headers: true)
canonical_portions = rows.select { |row| canonical_ids.include?(row['fdc_id']) }

# Write filtered CSV
CSV.open(OUTPUT_PORTION_CSV, 'w', write_headers: true, headers: rows.headers) do |csv|
  canonical_portions.each { |row| csv << row }
end

puts "Done! #{canonical_portions.size} portion records written to #{OUTPUT_PORTION_CSV}"
