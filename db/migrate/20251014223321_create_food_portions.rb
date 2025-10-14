class CreateFoodPortions < ActiveRecord::Migration[8.0]
  def change
    create_table :food_portions do |t|
      t.references :meal, null: false, foreign_key: true
      t.references :food, null: false, foreign_key: true
      t.decimal :grams, precision: 8, scale: 2, null: false

      t.timestamps
    end
  end
end
