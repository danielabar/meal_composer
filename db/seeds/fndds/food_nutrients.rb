require "csv"

# SLOW!

puts "Seeding FNDDS food nutrients..."
csv_path = Rails.root.join("db/data/fndds/food_nutrient.csv")
if File.exist?(csv_path)
  # Create a mapping from nutrient_nbr to the actual database id
  # This is needed because in FNDDS, food_nutrient.nutrient_id references nutrient.nutrient_nbr, not nutrient.id
  nutrient_nbr_to_id = {}
  Nutrient.find_each do |nutrient|
    # Safely parse the nutrient_nbr attribute
    if nutrient.respond_to?(:nutrient_nbr) && nutrient.nutrient_nbr.present?
      nutrient_nbr = nutrient.nutrient_nbr.to_s
      nutrient_nbr_to_id[nutrient_nbr] = nutrient.id
    end
  end

  # If the Nutrient model doesn't have nutrient_nbr column, we need to create a mapping using raw SQL
  if nutrient_nbr_to_id.empty?
    puts "  Creating nutrient mapping from CSV file..."
    nutrient_csv_path = Rails.root.join("db/data/fndds/nutrient.csv")
    CSV.foreach(nutrient_csv_path, headers: true) do |row|
      nutrient_id = row["id"].to_i
      nutrient_nbr = row["nutrient_nbr"].to_s
      nutrient_nbr_to_id[nutrient_nbr] = nutrient_id if nutrient_nbr.present?
    end
    puts "  Mapped #{nutrient_nbr_to_id.size} nutrients."
  end

  # Pre-load valid IDs for fast lookups
  valid_food_fdc_ids = Food.pluck(:fdc_id).to_set

  nutrient_count = 0
  skipped_count = 0

  CSV.foreach(csv_path, headers: true) do |row|
    fdc_id = row["fdc_id"].to_i
    nutrient_nbr = row["nutrient_id"].to_s

    # Look up the actual nutrient id using the mapping
    nutrient_id = nutrient_nbr_to_id[nutrient_nbr]

    # Skip if we couldn't find the nutrient or if the food doesn't exist
    unless nutrient_id.present? && valid_food_fdc_ids.include?(fdc_id)
      skipped_count += 1
      next
    end

    # Handle amount
    amount = row["amount"].present? ? [ row["amount"].to_f, 0.0 ].max : 0.0

    FoodNutrient.find_or_create_by!(fdc_id: fdc_id, nutrient_id: nutrient_id) do |fn|
      fn.amount = amount
      nutrient_count += 1
    end
  end

  puts "✅ #{nutrient_count} FNDDS food nutrients seeded (skipped #{skipped_count})."
  puts "  Note: If this count is 0, make sure your Nutrient model has a nutrient_nbr column."
else
  puts "⚠️ food_nutrient.csv not found in FNDDS data directory."
end
