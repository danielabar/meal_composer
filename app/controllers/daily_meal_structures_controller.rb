class DailyMealStructuresController < ApplicationController
  before_action :require_authentication
  before_action :set_daily_meal_structure, only: [ :edit, :update, :destroy ]

  def index
    @daily_meal_structures = Current.user.daily_meal_structures.order(created_at: :desc)
  end

  def new
    @daily_meal_structure = Current.user.daily_meal_structures.build
    # Pre-populate with 3 default meals
    @daily_meal_structure.meal_structure_items.build(meal_label: "breakfast", position: 0)
    @daily_meal_structure.meal_structure_items.build(meal_label: "lunch", position: 1)
    @daily_meal_structure.meal_structure_items.build(meal_label: "dinner", position: 2)
  end

  def create
    @daily_meal_structure = Current.user.daily_meal_structures.build(daily_meal_structure_params)

    if @daily_meal_structure.save
      redirect_to daily_meal_structures_path, notice: "Meal structure was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @daily_meal_structure.update(daily_meal_structure_params)
      redirect_to daily_meal_structures_path, notice: "Meal structure was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @daily_meal_structure.destroy
    redirect_to daily_meal_structures_path, notice: "Meal structure was successfully deleted."
  end

  private

  def set_daily_meal_structure
    @daily_meal_structure = Current.user.daily_meal_structures.find(params[:id])
  end

  def daily_meal_structure_params
    params.require(:daily_meal_structure).permit(
      :name,
      meal_structure_items_attributes: [
        :id,
        :meal_label,
        :position,
        :_destroy,
        food_category_ids: []
      ]
    )
  end
end
