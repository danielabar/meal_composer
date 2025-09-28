class Food < ApplicationRecord
  belongs_to :food_category

  validates :fdc_id, presence: true, uniqueness: true
  validates :description, presence: true
  validates :food_category, presence: true
  validates :publication_date, presence: true
end
