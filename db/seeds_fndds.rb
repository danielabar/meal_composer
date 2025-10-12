puts "🌱 FNDDS Dataset Seeding Started"

puts "Seeding food categories..."
load Rails.root.join("db/seeds/fndds/food_categories.rb")

puts "Seeding nutrients..."
load Rails.root.join("db/seeds/fndds/nutrients.rb")

puts "Seeding foods..."
load Rails.root.join("db/seeds/fndds/foods.rb")

puts "Seeding food nutrients..."
load Rails.root.join("db/seeds/fndds/food_nutrients.rb")

puts "Cleaning up food data..."
load Rails.root.join("db/seeds/fndds/cleanup.rb")

puts "🎉 FNDDS data seeding completed!"
