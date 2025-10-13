class CreateMealDefinitionCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :meal_definition_categories do |t|
      t.references :meal_definition, null: false, foreign_key: true
      t.references :food_category, null: false, foreign_key: true
      t.integer :position, null: false, default: 1

      t.timestamps
    end

    add_index :meal_definition_categories,
              [ :meal_definition_id, :food_category_id ],
              unique: true,
              name: 'index_meal_def_cats_on_meal_and_category'
    add_index :meal_definition_categories, [ :meal_definition_id, :position ]
  end
end
