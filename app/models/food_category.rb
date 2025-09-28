class FoodCategory < ApplicationRecord
  has_many :foods, dependent: :destroy

  validates :code, presence: true, uniqueness: true
  validates :description, presence: true
end
