puts "🧑 Seeding development user data..."

# Create development user
user = User.find_or_create_by!(email_address: "user@example.com") do |u|
  u.password = "Password123!"
end
puts "  ✅ User: #{user.email_address}"

# Seed sample macro targets for testing
strict_keto = DailyMacroTarget.find_or_create_by!(user: user, name: "Strict Keto") do |target|
  target.carbs_grams = 20
  target.protein_grams = 60
  target.fat_grams = 180
end
puts "  ✅ Macro Target: #{strict_keto.name}"

high_protein = DailyMacroTarget.find_or_create_by!(user: user, name: "High Protein Athlete") do |target|
  target.carbs_grams = 250
  target.protein_grams = 180
  target.fat_grams = 70
end
puts "  ✅ Macro Target: #{high_protein.name}"

# Seed sample Meal Structures
keto_structure = DailyMealStructure.find_or_create_by!(user: user, name: "Three Meals a Day for Keto Categories")

# Breakfast: Eggs and omelets, Butter and animal fats, Other dark green vegetables
breakfast_categories = FoodCategory.where(description: [
  "Eggs and omelets",
  "Butter and animal fats",
  "Other dark green vegetables"
]).pluck(:id)

MealStructureItem.find_or_create_by!(
  daily_meal_structure: keto_structure,
  meal_label: "breakfast"
) do |item|
  item.mode = "category"
  item.food_category_ids = breakfast_categories
end

# Lunch: Cold cuts and cured meats, Cheese, Lettuce and lettuce salads, Salad dressings and vegetable oils
lunch_categories = FoodCategory.where(description: [
  "Cold cuts and cured meats",
  "Cheese",
  "Lettuce and lettuce salads",
  "Salad dressings and vegetable oils"
]).pluck(:id)

MealStructureItem.find_or_create_by!(
  daily_meal_structure: keto_structure,
  meal_label: "lunch"
) do |item|
  item.mode = "category"
  item.food_category_ids = lunch_categories
end

# Dinner: Beef, excludes ground, Butter and animal fats, Other dark green vegetables
dinner_categories = FoodCategory.where(description: [
  "Beef, excludes ground",
  "Butter and animal fats",
  "Other dark green vegetables"
]).pluck(:id)

MealStructureItem.find_or_create_by!(
  daily_meal_structure: keto_structure,
  meal_label: "dinner"
) do |item|
  item.mode = "category"
  item.food_category_ids = dinner_categories
end

puts "  ✅ Meal Structure: #{keto_structure.name} (#{keto_structure.meal_structure_items.count} meals)"

# Seed Protein Athlete Meal Structure
athlete_structure = DailyMealStructure.find_or_create_by!(user: user, name: "Three Meals a Day for Protein Athlete Categories")

# Breakfast: Eggs and omelets, Butter and animal fats, Cheese, Oatmeal
athlete_breakfast_categories = FoodCategory.where(description: [
  "Eggs and omelets",
  "Butter and animal fats",
  "Oatmeal"
]).pluck(:id)

MealStructureItem.find_or_create_by!(
  daily_meal_structure: athlete_structure,
  meal_label: "breakfast"
) do |item|
  item.mode = "category"
  item.food_category_ids = athlete_breakfast_categories
end

# Lunch: Chicken, whole pieces, Lettuce and lettuce salads, Salad dressings and vegetable oils, Blueberries and other berries, Nuts and seeds
athlete_lunch_categories = FoodCategory.where(description: [
  "Chicken, whole pieces",
  "Salad dressings and vegetable oils",
  "Beans, peas, legumes"
]).pluck(:id)

MealStructureItem.find_or_create_by!(
  daily_meal_structure: athlete_structure,
  meal_label: "lunch"
) do |item|
  item.mode = "category"
  item.food_category_ids = athlete_lunch_categories
end

# Dinner: Ground beef, Rice, Butter and animal fats, Other red and orange vegetables, Melons
athlete_dinner_categories = FoodCategory.where(description: [
  "Ground beef",
  "Rice",
  "Butter and animal fats"
]).pluck(:id)

MealStructureItem.find_or_create_by!(
  daily_meal_structure: athlete_structure,
  meal_label: "dinner"
) do |item|
  item.mode = "category"
  item.food_category_ids = athlete_dinner_categories
end

puts "  ✅ Meal Structure: #{athlete_structure.name} (#{athlete_structure.meal_structure_items.count} meals)"

puts "🎉 Development user data seeded!"
