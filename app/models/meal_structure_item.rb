class MealStructureItem < ApplicationRecord
  MEAL_LABELS = {
    "breakfast" => "Breakfast",
    "brunch" => "Brunch",
    "lunch" => "Lunch",
    "dinner" => "Dinner",
    "snack" => "Snack"
  }.freeze

  MODES = {
    "category" => "Category-based (system selects random foods)",
    "food" => "Food-based (you select specific foods)"
  }.freeze

  belongs_to :daily_meal_structure

  validates :meal_label, presence: true
  validates :meal_label, inclusion: {
    in: MEAL_LABELS.keys,
    message: "%{value} is not a valid meal label"
  }

  validates :mode, presence: true, inclusion: {
    in: MODES.keys,
    message: "%{value} is not a valid mode"
  }

  # Validate that either food_category_ids or food_ids is present, but not both
  validate :has_either_categories_or_foods
  validate :food_categories_exist
  validate :foods_exist

  private

  def has_either_categories_or_foods
    has_categories = food_category_ids.present?
    has_foods = food_ids.present?

    if has_categories && has_foods
      errors.add(:base, "Cannot mix category and food selection within a meal")
    elsif !has_categories && !has_foods
      errors.add(:base, "Must select either categories or specific foods for a meal")
    end
  end

  def food_categories_exist
    return if food_category_ids.blank?

    existing_ids = FoodCategory.where(id: food_category_ids).pluck(:id)
    invalid_ids = food_category_ids - existing_ids

    if invalid_ids.any?
      errors.add(:food_category_ids, "contains invalid category IDs: #{invalid_ids.join(', ')}")
    end
  end

  def foods_exist
    return if food_ids.blank?

    existing_ids = Food.where(id: food_ids).pluck(:id)
    invalid_ids = food_ids - existing_ids

    if invalid_ids.any?
      errors.add(:food_ids, "contains invalid food IDs: #{invalid_ids.join(', ')}")
    end
  end
end
