class FoodCategory < ApplicationRecord
  # Associations
  # has_many :food_canonicals, foreign_key: :food_category_id, inverse_of: :food_category, dependent: :restrict_with_exception

  validates :code, presence: true, uniqueness: true
  validates :description, presence: true
end
