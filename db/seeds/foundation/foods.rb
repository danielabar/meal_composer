require "csv"

csv_path = Rails.root.join("db/data/foundation/food_canonical.csv")

CSV.foreach(csv_path, headers: true) do |row|
  Food.find_or_create_by!(fdc_id: row["fdc_id"].to_i) do |food|
    food.description       = row["description"]
    food.food_category_id  = row["food_category_id"].to_i
    food.publication_date  = row["publication_date"]
  end
end
