require "csv"

csv_path = Rails.root.join("db/data/nutrient.csv")

CSV.foreach(csv_path, headers: true) do |row|
  Nutrient.find_or_create_by!(id: row["id"].to_i) do |nutrient|
    nutrient.name = row["name"]
    nutrient.unit_name = row["unit_name"]
    nutrient.rank = row["rank"].present? ? row["rank"].to_f : 999999.0
  end
end
