# This is the main cleanup file that orchestrates all FNDDS data cleanup operations
# It loads individual cleanup scripts in the appropriate sequence

puts "Starting FNDDS data cleanup process..."

puts "Step 1: Removing baby/infant food items..."
load Rails.root.join("db/seeds/fndds/cleanup_baby_foods.rb")

puts "Step 2: Cleaning up composite food items..."
load Rails.root.join("db/seeds/fndds/cleanup_composite_foods.rb")

puts "Step 3: Removing fast food and restaurant items..."
load Rails.root.join("db/seeds/fndds/cleanup_restaurant_foods.rb")

puts "✅ FNDDS data cleanup completed!"
