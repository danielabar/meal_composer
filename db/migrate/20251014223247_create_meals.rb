class CreateMeals < ActiveRecord::Migration[8.0]
  def change
    create_table :meals do |t|
      t.references :daily_meal_plan, null: false, foreign_key: true
      t.string :meal_type, null: false
      t.decimal :actual_carbs_grams, precision: 8, scale: 2, null: false
      t.decimal :actual_protein_grams, precision: 8, scale: 2, null: false
      t.decimal :actual_fat_grams, precision: 8, scale: 2, null: false

      t.timestamps
    end

    add_index :meals, [ :daily_meal_plan_id, :meal_type ], unique: true
  end
end
