require "csv"

csv_path = Rails.root.join("db/data/foundation/food_category.csv")

CSV.foreach(csv_path, headers: true) do |row|
  FoodCategory.find_or_create_by!(id: row["id"].to_i) do |fc|
    fc.code = row["code"]
    fc.description = row["description"]
  end
end
