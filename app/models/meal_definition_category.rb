class MealDefinitionCategory < ApplicationRecord
  belongs_to :meal_definition
  belongs_to :food_category

  validates :position, presence: true, numericality: { only_integer: true }
  validates :food_category_id, uniqueness: {
    scope: :meal_definition_id,
    message: "has already been added to this meal"
  }

  # TODO: Can this be accomplished without a default scope?
  default_scope { order(position: :asc) }
end
