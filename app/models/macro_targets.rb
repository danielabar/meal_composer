class MacroTargets
  attr_accessor :carbs, :protein, :fat

  def initialize(carbs:, protein:, fat:)
    @carbs = carbs.to_f
    @protein = protein.to_f
    @fat = fat.to_f
  end

  def dup
    MacroTargets.new(carbs: carbs, protein: protein, fat: fat)
  end

  def to_s
    "#{carbs}g carbs, #{protein}g protein, #{fat}g fat"
  end
end
