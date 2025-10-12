require "csv"

puts "Seeding FNDDS foods..."
csv_path = Rails.root.join("db/data/fndds/food.csv")
food_count = 0
skipped_count = 0

CSV.foreach(csv_path, headers: true) do |row|
  fdc_id = row["fdc_id"]
  wweia_category_code = row["food_category_id"]

  # Look up the category directly from the database
  food_category = FoodCategory.find_by(code: "WWEIA_#{wweia_category_code}")

  # Skip if we couldn't find the category
  if food_category.nil?
    skipped_count += 1
    next
  end

  category_id = food_category.id

  Food.find_or_create_by!(fdc_id: fdc_id.to_i) do |food|
    food.description = row["description"]
    food.food_category_id = category_id
    food.publication_date = row["publication_date"]
    food_count += 1
  end
end
puts "✅ #{food_count} FNDDS foods seeded (skipped #{skipped_count})."
