class CreateFoodNutrients < ActiveRecord::Migration[8.0]
  def change
    create_table :food_nutrients do |t|
      t.integer :fdc_id, null: false
      t.references :nutrient, null: false, foreign_key: true
      t.decimal :amount, precision: 15, scale: 6

      t.timestamps
    end

    add_index :food_nutrients, [ :fdc_id, :nutrient_id ], unique: true
    add_index :food_nutrients, :fdc_id

    add_foreign_key :food_nutrients, :foods, column: :fdc_id, primary_key: :fdc_id
  end
end
