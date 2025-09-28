class FoodNutrient < ApplicationRecord
  belongs_to :food, foreign_key: :fdc_id, primary_key: :fdc_id
  belongs_to :nutrient

  validates :fdc_id, presence: true
  validates :nutrient_id, presence: true
  validates :fdc_id, uniqueness: { scope: :nutrient_id }
  validates :amount, presence: true, numericality: {
    greater_than_or_equal_to: 0,
    less_than: 1_000_000_000  # 999,999,999 max with precision 15, scale 6
  }
end
