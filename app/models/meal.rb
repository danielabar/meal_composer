class Meal < ApplicationRecord
  MEAL_TYPES = %w[breakfast lunch dinner brunch snack].freeze

  belongs_to :daily_meal_plan
  has_many :food_portions, dependent: :destroy

  validates :meal_type, presence: true, inclusion: { in: MEAL_TYPES }
  validates :actual_carbs_grams, :actual_protein_grams, :actual_fat_grams,
            presence: true,
            numericality: { greater_than_or_equal_to: 0 }
  validates :meal_type, uniqueness: { scope: :daily_meal_plan_id }

  # Total weight of all food in this meal
  def total_grams
    food_portions.sum(&:grams)
  end

  # Number of food items in this meal
  def food_count
    food_portions.count
  end

  # Human-readable meal type
  def meal_type_label
    meal_type.capitalize
  end
end
