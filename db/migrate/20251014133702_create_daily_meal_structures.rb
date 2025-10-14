class CreateDailyMealStructures < ActiveRecord::Migration[8.0]
  def change
    create_table :daily_meal_structures do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.timestamps
    end

    add_index :daily_meal_structures, [:user_id, :name], unique: true

    create_table :meal_structure_items do |t|
      t.references :daily_meal_structure, null: false, foreign_key: true
      t.string :meal_label, null: false
      t.integer :food_category_ids, array: true, default: [], null: false
      t.integer :position, default: 0
      t.timestamps
    end

    add_index :meal_structure_items, :food_category_ids, using: 'gin'
  end
end
