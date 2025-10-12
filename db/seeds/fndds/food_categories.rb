require "csv"

puts "Seeding WWEIA food categories..."
csv_path = Rails.root.join("db/data/fndds/wweia_food_category.csv")
category_count = 0

CSV.foreach(csv_path, headers: true) do |row|
  category_code = row["wweia_food_category"]
  description = row["wweia_food_category_description"]

  FoodCategory.find_or_create_by!(code: "WWEIA_#{category_code}") do |fc|
    fc.description = description
    category_count += 1
  end
end
puts "✅ #{category_count} WWEIA food categories seeded."
