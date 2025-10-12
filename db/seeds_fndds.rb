puts "🌱 FNDDS Dataset Seeding Started"

puts "Seeding food categories..."
load Rails.root.join("db/seeds/fndds/food_categories.rb")

puts "Seeding nutrients..."
load Rails.root.join("db/seeds/fndds/nutrients.rb")

puts "Seeding foods..."
load Rails.root.join("db/seeds/fndds/foods.rb")

puts "Seeding food nutrients..."
load Rails.root.join("db/seeds/fndds/food_nutrients.rb")

# TODO: Add a cleanup task to remove foods no adult would eat (eg: human milk, baby food, etc.)
# Remove combination foods (`with`, `and`, `includes`, `added`)
# Figure out that butter & animals fats category, like what is "table fat"?

puts "🎉 FNDDS data seeding completed!"
