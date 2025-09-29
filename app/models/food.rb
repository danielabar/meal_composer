class Food < ApplicationRecord
  belongs_to :food_category
  has_many :food_nutrients, foreign_key: :fdc_id, primary_key: :fdc_id, dependent: :destroy
  has_many :nutrients, through: :food_nutrients

  validates :fdc_id, presence: true, uniqueness: true
  validates :description, presence: true
  validates :food_category, presence: true
  validates :publication_date, presence: true

  # DEPRECATED
  # def macronutrients(pretty: false)
  #   @carb_nutrient ||= Nutrient.find_by(name: "Carbohydrate, by difference", unit_name: "G")
  #   @protein_nutrient ||= Nutrient.find_by(name: "Protein", unit_name: "G")
  #   @fat_nutrient ||= Nutrient.find_by(name: "Total lipid (fat)", unit_name: "G")

  #   carbs = @carb_nutrient ? food_nutrients.find_by(nutrient_id: @carb_nutrient.id)&.amount : nil
  #   protein = @protein_nutrient ? food_nutrients.find_by(nutrient_id: @protein_nutrient.id)&.amount : nil
  #   fat = @fat_nutrient ? food_nutrients.find_by(nutrient_id: @fat_nutrient.id)&.amount : nil

  #   result = {
  #     carbohydrates: carbs,
  #     protein: protein,
  #     fat: fat
  #   }

  #   if pretty
  #     formatted_result = result.transform_values do |value|
  #       value ? "#{value.to_f.round(2)}g" : "N/A"
  #     end

  #     puts "Macronutrients for #{description}:"
  #     puts "  Carbohydrates: #{formatted_result[:carbohydrates]}"
  #     puts "  Protein: #{formatted_result[:protein]}"
  #     puts "  Fat: #{formatted_result[:fat]}"

  #     formatted_result
  #   else
  #     result
  #   end
  # end
end
