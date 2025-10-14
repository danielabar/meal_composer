require "csv"

# FAST version using Rails built-in insert_all for bulk inserts

puts "Seeding FNDDS foods (fast bulk insert)..."
csv_path = Rails.root.join("db/data/fndds/food_clean.csv")

if File.exist?(csv_path)
  # Pre-load all food categories into a hash for O(1) lookups
  # This avoids ~5,500 individual database queries
  puts "  Loading food categories..."
  category_code_to_id = {}
  FoodCategory.find_each do |category|
    # FNDDS categories are prefixed with "WWEIA_" in the database
    # but the CSV just has the numeric code
    if category.code.start_with?("WWEIA_")
      wweia_code = category.code.sub("WWEIA_", "")
      category_code_to_id[wweia_code] = category.id
    end
  end
  puts "  Mapped #{category_code_to_id.size} food categories."

  food_count = 0
  skipped_count = 0
  batch = []
  BATCH_SIZE = 1000  # Smaller than nutrients since foods have more columns/indexes
  timestamp = Time.current

  puts "  Processing CSV rows..."
  CSV.foreach(csv_path, headers: true) do |row|
    fdc_id = row["fdc_id"].to_i
    wweia_category_code = row["food_category_id"]

    # Look up the category ID from our pre-loaded hash
    category_id = category_code_to_id[wweia_category_code]

    # Skip if we couldn't find the category
    unless category_id.present?
      skipped_count += 1
      next
    end

    batch << {
      fdc_id: fdc_id,
      description: row["description"],
      food_category_id: category_id,
      publication_date: row["publication_date"],
      created_at: timestamp,
      updated_at: timestamp
    }

    if batch.size >= BATCH_SIZE
      Food.insert_all(batch, unique_by: :fdc_id)
      food_count += batch.size
      batch.clear
      print "."  # Progress indicator
    end
  end

  # Insert remaining records
  if batch.any?
    Food.insert_all(batch, unique_by: :fdc_id)
    food_count += batch.size
  end

  puts "\n✅ #{food_count} FNDDS foods seeded (skipped #{skipped_count})."
else
  puts "⚠️ food_clean.csv not found in FNDDS data directory."
end
