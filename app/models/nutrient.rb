class Nutrient < ApplicationRecord
  validates :name, presence: true
  validates :unit_name, presence: true
  validates :rank, presence: true, numericality: true
  validates :name, uniqueness: { scope: :unit_name }
end
