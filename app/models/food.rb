class Food < ApplicationRecord
  belongs_to :food_category
  has_many :food_nutrients, foreign_key: :fdc_id, primary_key: :fdc_id, dependent: :destroy
  has_many :nutrients, through: :food_nutrients

  validates :fdc_id, presence: true, uniqueness: true
  validates :description, presence: true
  validates :food_category, presence: true
  validates :publication_date, presence: true
end
