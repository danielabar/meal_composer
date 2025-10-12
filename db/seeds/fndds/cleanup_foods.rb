# This script is responsible for cleaning up the FNDDS food data
# by removing entries that are not relevant for adult meal planning.

puts "Starting FNDDS food data cleanup..."

# Remove foods no adult would typically eat
puts "Removing foods not suitable for adult meal planning..."

# Define keywords for foods to remove
unsuitable_food_keywords = [
  'human',   # e.g. 'Milk, human'
  'infant',  # infant formula, etc.
  'baby',    # baby food
  'toddler'  # toddler-specific foods
]

# Track how many records we're removing
removed_count = 0

# Remove foods that match our keywords
unsuitable_food_keywords.each do |keyword|
  # Find foods with the keyword in their description
  foods_to_remove = Food.where("lower(description) LIKE ?", "%#{keyword}%")

  # Log what we're removing
  if foods_to_remove.any?
    puts "- Removing #{foods_to_remove.count} food(s) containing '#{keyword}':"
    foods_to_remove.each do |food|
      puts "  * #{food.id}: #{food.description} (Category: #{food.food_category_id})"
    end

    # Remove the foods (which will cascade to food_nutrients due to dependent: :destroy)
    removed_count += foods_to_remove.count
    foods_to_remove.destroy_all
  end
end

puts "✅ Removed #{removed_count} unsuitable foods"

# TODO: Remove combination foods that contain complex descriptions
#   - Foods with keywords like `with`, `and`, `includes`, `added`
#   - These are often too specific for general meal planning purposes
#   - WATCH OUT: some `and` is desirable, needs more work

# TODO: Investigate and cleanup the butter & animal fats category
#   - Determine what items like "table fat" actually refer to
#   - Standardize naming and categorization for consistency

puts "FNDDS food data cleanup completed!"
