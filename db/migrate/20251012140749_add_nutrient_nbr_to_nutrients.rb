class AddNutrientNbrToNutrients < ActiveRecord::Migration[8.0]
  def change
    add_column :nutrients, :nutrient_nbr, :string
    add_index :nutrients, :nutrient_nbr
  end
end
