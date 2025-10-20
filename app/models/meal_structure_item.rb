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

  MIN_FOODS = 2
  MAX_FOODS = 5

  belongs_to :daily_meal_structure

  validates :meal_label, presence: true
  validates :meal_label, inclusion: {
    in: MEAL_LABELS.keys,
    message: "%{value} is not a valid meal label"
  }

  validates :mode, inclusion: {
    in: MODES.keys,
    message: "%{value} is not a valid mode"
  }

  # Validate that the correct field is present based on mode
  validate :validate_by_mode
  validate :food_categories_exist
  validate :foods_exist

  private

  def validate_by_mode
    case mode
    when "category"
      if food_category_ids.blank?
        errors.add(:food_category_ids, "required - select at least one category")
      end
    when "food"
      if food_ids.blank?
        errors.add(:food_ids, "required - select at least one food")
      end
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
