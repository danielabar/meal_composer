class AddFoodSelectionToMealStructureItems < ActiveRecord::Migration[8.0]
  def change
    # food_ids: integer array to store IDs of explicitly selected foods
    add_column :meal_structure_items, :food_ids, :integer, array: true, default: []

    # mode: simple string ("category" or "food") - keeps it flexible for experimentation
    add_column :meal_structure_items, :mode, :string, default: "category"
  end
end
