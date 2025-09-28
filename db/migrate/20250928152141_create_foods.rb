class CreateFoods < ActiveRecord::Migration[8.0]
  def change
    create_table :foods do |t|
      t.integer :fdc_id, null: false, index: { unique: true }
      t.text :description, null: false
      t.references :food_category, null: false, foreign_key: true
      t.date :publication_date, null: false

      t.timestamps
    end
  end
end
