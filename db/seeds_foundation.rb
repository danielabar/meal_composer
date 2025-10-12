puts "🌱 Seeding Foundation Foods Dataset..."

puts "Seeding food categories..."
load Rails.root.join("db/seeds/foundation/food_categories.rb")
puts "✅ Food categories seeded."

puts "Seeding nutrients..."
load Rails.root.join("db/seeds/foundation/nutrients.rb")
puts "✅ Nutrients seeded."

puts "Seeding foods..."
load Rails.root.join("db/seeds/foundation/foods.rb")
puts "✅ Foods seeded."

puts "Seeding food nutrients..."
load Rails.root.join("db/seeds/foundation/food_nutrients.rb")
puts "✅ Food nutrients seeded."

puts "🎉 Foundation Foods dataset seeding completed!"
