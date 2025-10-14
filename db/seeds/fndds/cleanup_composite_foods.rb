# TODO: No longer needed
# This script is responsible for cleaning up composite foods
# that are too specific for general meal planning purposes

puts "Starting cleanup of composite food items..."

# For now, we're focusing on removing foods with 'with' in their descriptions
# These are typically combination foods that are too specific for general meal planning

# Track how many records we're removing
removed_count = 0

# Find foods with 'with' in their description
foods_with_with = Food.where("lower(description) LIKE ?", "%with%")

# Log what we're removing
if foods_with_with.any?
  puts "- Found #{foods_with_with.count} food(s) containing 'with':"

  # Sample output for the first few items (to avoid overwhelming logs)
  sample_size = [ foods_with_with.count, 10 ].min
  foods_with_with.limit(sample_size).each do |food|
    puts "  * #{food.id}: #{food.description} (Category: #{food.food_category_id})"
  end

  if foods_with_with.count > sample_size
    puts "  * ... and #{foods_with_with.count - sample_size} more"
  end

  # Remove the foods (which will cascade to food_nutrients due to dependent: :destroy)
  removed_count = foods_with_with.count
  foods_with_with.destroy_all

  puts "✅ Removed #{removed_count} composite foods containing 'with'"
else
  puts "No foods with 'with' in their description were found"
end

# TODO: Future enhancements to this cleanup could include:
#  - Handling other keywords like 'and', 'includes', 'added'
#  - More sophisticated filtering rules (some combinations are legitimate)
#  - Category-based filtering for certain types of composite foods

puts "✅ Completed composite foods cleanup"
