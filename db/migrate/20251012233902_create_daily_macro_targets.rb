class CreateDailyMacroTargets < ActiveRecord::Migration[8.0]
  def change
    create_table :daily_macro_targets do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :carbs_grams, precision: 8, scale: 2, null: false
      t.decimal :protein_grams, precision: 8, scale: 2, null: false
      t.decimal :fat_grams, precision: 8, scale: 2, null: false

      t.timestamps
    end

    add_index :daily_macro_targets, [ :user_id, :name ], unique: true
  end
end
