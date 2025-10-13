class DailyMacroTarget < ApplicationRecord
  belongs_to :user

  validates :name, presence: true
  validates :carbs_grams, :protein_grams, :fat_grams,
            presence: true,
            numericality: { greater_than_or_equal_to: 0 }
  validates :name, uniqueness: { scope: :user_id }

  # Derived calories (4 cal/g for carbs & protein, 9 cal/g for fat)
  def total_calories
    ((carbs_grams * 4) + (protein_grams * 4) + (fat_grams * 9)).round
  end

  def to_macro_targets
    MacroTargets.new(
      carbs: carbs_grams,
      protein: protein_grams,
      fat: fat_grams
    )
  end
end
