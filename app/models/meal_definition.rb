class MealDefinition < ApplicationRecord
  belongs_to :daily_meal_structure
  has_many :meal_definition_categories, dependent: :destroy
  has_many :food_categories, through: :meal_definition_categories

  validates :label, presence: true
  validates :position, presence: true, numericality: { only_integer: true }
  validates :label, uniqueness: { scope: :daily_meal_structure_id }

  # For nested form handling
  accepts_nested_attributes_for :meal_definition_categories,
                                allow_destroy: true,
                                reject_if: :all_blank

  # TODO: Can this be accomplished without a default scope?
  default_scope { order(position: :asc) }

  # Ensure at least one food category
  validate :must_have_at_least_one_category

  private

  def must_have_at_least_one_category
    if meal_definition_categories.reject(&:marked_for_destruction?).empty?
      errors.add(:base, "must have at least one food category")
    end
  end
end
