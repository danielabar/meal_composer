class MealStructureItem < ApplicationRecord
  MEAL_LABELS = {
    "breakfast" => "Breakfast",
    "brunch" => "Brunch",
    "lunch" => "Lunch",
    "dinner" => "Dinner",
    "snack" => "Snack"
  }.freeze

  belongs_to :daily_meal_structure

  validates :meal_label, presence: true
  validates :food_category_ids, presence: true
  validate :food_categories_exist

  # Ensure meal_label is one of the expected values (can be relaxed later)
  validates :meal_label, inclusion: {
    in: MEAL_LABELS.keys,
    message: "%{value} is not a valid meal label"
  }

  private

  def food_categories_exist
    return if food_category_ids.blank?

    existing_ids = FoodCategory.where(id: food_category_ids).pluck(:id)
    invalid_ids = food_category_ids - existing_ids

    if invalid_ids.any?
      errors.add(:food_category_ids, "contains invalid category IDs: #{invalid_ids.join(', ')}")
    end
  end
end
