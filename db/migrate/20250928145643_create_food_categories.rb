class CreateFoodCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :food_categories, id: :bigint do |t|
      t.text :code, null: false
      t.text :description, null: false

      t.timestamps
    end

    add_index :food_categories, :code, unique: true
  end
end
