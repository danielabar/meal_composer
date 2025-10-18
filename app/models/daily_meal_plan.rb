class DailyMealPlan < ApplicationRecord
  belongs_to :user
  belongs_to :daily_macro_target
  belongs_to :daily_meal_structure
  has_many :meals, dependent: :destroy

  validates :name, presence: true
  validates :name, uniqueness: { scope: :user_id }
  validates :target_carbs_grams, :target_protein_grams, :target_fat_grams,
            :actual_carbs_grams, :actual_protein_grams, :actual_fat_grams,
            presence: true,
            numericality: { greater_than_or_equal_to: 0 }

  # Helper method to check if macros are within acceptable tolerance
  def within_tolerance?
    tolerance = FlexibleMealComposer::MACRO_TOLERANCE_GRAMS

    (actual_carbs_grams - target_carbs_grams).abs <= tolerance &&
    (actual_protein_grams - target_protein_grams).abs <= tolerance &&
    (actual_fat_grams - target_fat_grams).abs <= tolerance
  end

  # Total weight of all food in grams
  def total_grams
    meals.sum(&:total_grams)
  end

  # Total number of individual food items across all meals
  def total_foods
    meals.sum(&:food_count)
  end

  # Calculate differences between target and actual macros
  def macro_differences
    {
      carbs: actual_carbs_grams - target_carbs_grams,
      protein: actual_protein_grams - target_protein_grams,
      fat: actual_fat_grams - target_fat_grams
    }
  end
end
