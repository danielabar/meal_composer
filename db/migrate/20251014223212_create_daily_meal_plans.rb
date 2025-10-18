class CreateDailyMealPlans < ActiveRecord::Migration[8.0]
  def change
    create_table :daily_meal_plans do |t|
      t.references :user, null: false, foreign_key: true
      t.references :daily_macro_target, null: false, foreign_key: true
      t.references :daily_meal_structure, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :target_carbs_grams, precision: 8, scale: 2, null: false
      t.decimal :target_protein_grams, precision: 8, scale: 2, null: false
      t.decimal :target_fat_grams, precision: 8, scale: 2, null: false
      t.decimal :actual_carbs_grams, precision: 8, scale: 2, null: false
      t.decimal :actual_protein_grams, precision: 8, scale: 2, null: false
      t.decimal :actual_fat_grams, precision: 8, scale: 2, null: false
      t.boolean :within_tolerance, null: false, default: false

      t.timestamps
    end

    add_index :daily_meal_plans, [ :user_id, :name ], unique: true
  end
end
