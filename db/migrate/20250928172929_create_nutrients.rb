class CreateNutrients < ActiveRecord::Migration[8.0]
  def change
    create_table :nutrients, id: :bigint do |t|
      t.text :name, null: false
      t.text :unit_name, null: false
      t.decimal :rank, precision: 10, scale: 1, null: false

      t.timestamps
    end

    add_index :nutrients, [ :name, :unit_name ], unique: true
    add_index :nutrients, :rank
  end
end
