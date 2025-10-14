class DailyMealStructure < ApplicationRecord
  belongs_to :user
  has_many :meal_structure_items, dependent: :destroy

  validates :name, presence: true
  validates :name, uniqueness: { scope: :user_id }

  # Accepts nested attributes for Hotwire forms
  accepts_nested_attributes_for :meal_structure_items,
                                allow_destroy: true,
                                reject_if: :all_blank
end
