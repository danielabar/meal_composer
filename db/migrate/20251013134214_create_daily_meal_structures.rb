class CreateDailyMealStructures < ActiveRecord::Migration[8.0]
  def change
    create_table :daily_meal_structures do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    add_index :daily_meal_structures, [ :user_id, :name ], unique: true
  end
end
