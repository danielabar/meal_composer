#!/usr/bin/env ruby
# Extract canonical foods (foundation_food) from Food Central CSV

require 'csv'

# Paths
INPUT_CSV  = 'db/data/food.csv'
OUTPUT_CSV = 'db/data/food_canonical.csv'

# Read and filter CSV
puts "Processing #{INPUT_CSV}..."
rows = CSV.read(INPUT_CSV, headers: true)
canonical_rows = rows.select { |row| row['data_type'] == 'foundation_food' }

# Write filtered CSV
CSV.open(OUTPUT_CSV, 'w', write_headers: true, headers: rows.headers) do |csv|
  canonical_rows.each { |row| csv << row }
end

puts "Done! #{canonical_rows.size} canonical foods written to #{OUTPUT_CSV}"
