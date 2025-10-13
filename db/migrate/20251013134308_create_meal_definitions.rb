class CreateMealDefinitions < ActiveRecord::Migration[8.0]
  def change
    create_table :meal_definitions do |t|
      t.references :daily_meal_structure, null: false, foreign_key: true
      t.string :label, null: false
      t.integer :position, null: false, default: 1

      t.timestamps
    end

    add_index :meal_definitions, [ :daily_meal_structure_id, :label ],
              unique: true, name: 'index_meal_defs_on_structure_and_label'
    add_index :meal_definitions, [ :daily_meal_structure_id, :position ]
  end
end
