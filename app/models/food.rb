class Food < ApplicationRecord
  belongs_to :food_category
  has_many :food_nutrients, foreign_key: :fdc_id, primary_key: :fdc_id, dependent: :destroy
  has_many :nutrients, through: :food_nutrients

  validates :fdc_id, presence: true, uniqueness: true
  validates :description, presence: true
  validates :food_category, presence: true
  validates :publication_date, presence: true

  def macronutrients
    @carb_nutrient ||= Nutrient.find_by(name: "Carbohydrate, by difference", unit_name: "G")
    @protein_nutrient ||= Nutrient.find_by(name: "Protein", unit_name: "G")
    @fat_nutrient ||= Nutrient.find_by(name: "Total lipid (fat)", unit_name: "G")

    {
      carbohydrates: @carb_nutrient ? food_nutrients.find_by(nutrient_id: @carb_nutrient.id)&.amount : nil,
      protein: @protein_nutrient ? food_nutrients.find_by(nutrient_id: @protein_nutrient.id)&.amount : nil,
      fat: @fat_nutrient ? food_nutrients.find_by(nutrient_id: @fat_nutrient.id)&.amount : nil
    }
  end
end
