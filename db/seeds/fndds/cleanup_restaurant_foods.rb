# TODO: No longer needed
# This script is responsible for removing FNDDS food data
# related to fast food restaurants and restaurant items
# These are often branded items or highly variable in nutrition

puts "Starting cleanup of fast food and restaurant items..."

# Define keywords for foods to remove
restaurant_food_keywords = [
  'fast food',   # e.g. 'Fast food, hamburger'
  'restaurant'   # e.g. 'Restaurant, pasta dish'
]

# Track how many records we're removing
removed_count = 0

# Remove foods that match our keywords
restaurant_food_keywords.each do |keyword|
  # Find foods with the keyword in their description
  foods_to_remove = Food.where("lower(description) LIKE ?", "%#{keyword}%")

  # Log what we're removing
  if foods_to_remove.any?
    puts "- Removing #{foods_to_remove.count} food(s) containing '#{keyword}':"

    # Sample output for the first few items (to avoid overwhelming logs)
    sample_size = [ foods_to_remove.count, 10 ].min
    foods_to_remove.limit(sample_size).each do |food|
      puts "  * #{food.id}: #{food.description} (Category: #{food.food_category_id})"
    end

    if foods_to_remove.count > sample_size
      puts "  * ... and #{foods_to_remove.count - sample_size} more"
    end

    # Remove the foods (which will cascade to food_nutrients due to dependent: :destroy)
    removed_count += foods_to_remove.count
    foods_to_remove.destroy_all
  else
    puts "- No foods found containing '#{keyword}'"
  end
end

puts "✅ Removed #{removed_count} fast food and restaurant items"
