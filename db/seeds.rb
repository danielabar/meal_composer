puts "Seeding food categories..."
load Rails.root.join("db/seeds/food_categories.rb")
puts "✅ Food categories seeded."

puts "Seeding foods..."
load Rails.root.join("db/seeds/foods.rb")
puts "✅ Foods seeded."

puts "All seeds finished!"
