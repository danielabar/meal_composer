class ChangeDefaultsForDailyMacroTargets < ActiveRecord::Migration[8.0]
  def change
    change_column_default :daily_macro_targets, :carbs_grams, from: nil, to: 0
    change_column_default :daily_macro_targets, :protein_grams, from: nil, to: 0
    change_column_default :daily_macro_targets, :fat_grams, from: nil, to: 0
  end
end
