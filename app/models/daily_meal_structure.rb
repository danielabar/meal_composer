class DailyMealStructure < ApplicationRecord
  belongs_to :user
  has_many :meal_definitions, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :user_id }

  # For nested form handling
  accepts_nested_attributes_for :meal_definitions,
                                allow_destroy: true,
                                reject_if: :all_blank

  # Convert to the format FlexibleMealComposer expects
  def to_meal_structure_hash
    meal_definitions.each_with_object({}) do |meal_def, hash|
      hash[meal_def.label.to_sym] = meal_def.food_categories.pluck(:description)
    end
  end
end
