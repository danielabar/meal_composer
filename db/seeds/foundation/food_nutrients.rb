require "csv"

csv_path = Rails.root.join("db/data/foundation/food_nutrient_canonical.csv")

# Preload all valid IDs into memory sets for fast lookup (eliminates N+1 queries)
puts "🔄 Preloading reference data..."
valid_nutrient_ids = Nutrient.pluck(:id).to_set
valid_food_fdc_ids = Food.pluck(:fdc_id).to_set
puts "   ✅ Loaded #{valid_nutrient_ids.size} valid nutrient IDs"
puts "   ✅ Loaded #{valid_food_fdc_ids.size} valid food FDC IDs"

skipped_count = 0
processed_count = 0
clamped_count = 0

CSV.foreach(csv_path, headers: true).with_index(2) do |row, line_number|
  begin
    fdc_id = row["fdc_id"].to_i
    nutrient_id = row["nutrient_id"].to_i

    # Check if the nutrient exists (fast in-memory lookup)
    unless valid_nutrient_ids.include?(nutrient_id)
      puts "⚠️  Skipping line #{line_number}: Nutrient ID #{nutrient_id} not found"
      skipped_count += 1
      next
    end

    # Check if the food exists (fast in-memory lookup)
    unless valid_food_fdc_ids.include?(fdc_id)
      puts "⚠️  Skipping line #{line_number}: Food FDC ID #{fdc_id} not found"
      skipped_count += 1
      next
    end

    # Parse and clamp amount to 0.0 if negative
    raw_amount = row["amount"].present? ? row["amount"].to_f : 0.0
    if raw_amount < 0.0
      puts "🔧 Clamping negative value to 0.0 on line #{line_number}: fdc_id=#{fdc_id}, nutrient_id=#{nutrient_id}, original_amount=#{raw_amount}"
      clamped_amount = 0.0
      clamped_count += 1
    else
      clamped_amount = raw_amount
    end

    # Skip the original 'id' column, let Rails generate AR PK
    FoodNutrient.find_or_create_by!(
      fdc_id: fdc_id,
      nutrient_id: nutrient_id
    ) do |food_nutrient|
      food_nutrient.amount = clamped_amount
    end

    processed_count += 1
  rescue => e
    puts "❌ Error processing line #{line_number}:"
    puts "   Row data: #{row.to_h}"
    puts "   fdc_id: #{row['fdc_id']} (#{row['fdc_id'].to_i})"
    puts "   nutrient_id: #{row['nutrient_id']} (#{row['nutrient_id'].to_i})"
    puts "   amount: #{row['amount']} (#{row['amount'].present? ? row['amount'].to_f : 0.0})"
    puts "   Error: #{e.class} - #{e.message}"
    puts ""

    # Re-raise to stop execution for unexpected errors
    raise e
  end
end

puts "📊 Food nutrients seeding completed:"
puts "   ✅ Processed: #{processed_count} records"
puts "   ⚠️  Skipped: #{skipped_count} records (missing nutrient or food references)"
puts "   🔧 Clamped: #{clamped_count} records (negative values set to 0.0)"
