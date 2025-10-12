require "csv"

puts "Seeding FNDDS nutrients..."
csv_path = Rails.root.join("db/data/fndds/nutrient.csv")
if File.exist?(csv_path)
  # Check if Nutrient model has nutrient_nbr column
  has_nutrient_nbr = Nutrient.column_names.include?("nutrient_nbr")
  if !has_nutrient_nbr
    puts "⚠️ Warning: Nutrient model does not have a nutrient_nbr column."
    puts "  You may need to create a migration to add this column for proper FNDDS mapping:"
    puts "  rails g migration AddNutrientNbrToNutrients nutrient_nbr:string"
    puts "  This column is crucial for mapping food nutrients correctly."
  end

  nutrient_count = 0
  CSV.foreach(csv_path, headers: true) do |row|
    nutrient = Nutrient.find_or_initialize_by(id: row["id"].to_i)

    nutrient.name = row["name"]
    nutrient.unit_name = row["unit_name"]
    nutrient.rank = row["rank"].present? ? row["rank"].to_f : 999999.0

    # Store nutrient_nbr if the column exists
    if has_nutrient_nbr
      nutrient.nutrient_nbr = row["nutrient_nbr"]
    end

    if nutrient.save
      nutrient_count += 1
    end
  end
  puts "✅ #{nutrient_count} FNDDS nutrients seeded."
else
  puts "⚠️ nutrient.csv not found in FNDDS data directory."
end
