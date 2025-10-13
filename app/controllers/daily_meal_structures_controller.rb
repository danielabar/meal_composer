class DailyMealStructuresController < ApplicationController
  before_action :require_authentication
  before_action :set_daily_meal_structure, only: [ :show, :edit, :update, :destroy, :duplicate ]

  def index
    @daily_meal_structures = Current.user.daily_meal_structures.includes(meal_definitions: :food_categories)
    @daily_meal_structure = DailyMealStructure.new
  end

  def show
    # Could be used for a detailed view, or just redirect to index
    redirect_to daily_meal_structures_path
  end

  def new
    @daily_meal_structure = Current.user.daily_meal_structures.build
    # Build one meal with one category to start
    meal = @daily_meal_structure.meal_definitions.build(position: 0)
    meal.meal_definition_categories.build(position: 0)
    @food_categories = FoodCategory.order(:description)
  end

  def create
    @daily_meal_structure = Current.user.daily_meal_structures.build(daily_meal_structure_params)

    if @daily_meal_structure.save
      respond_to do |format|
        format.html { redirect_to daily_meal_structures_path, notice: "Meal structure created successfully." }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.prepend("daily_meal_structures_list",
              partial: "daily_meal_structures/daily_meal_structure",
              locals: { daily_meal_structure: @daily_meal_structure }),
            turbo_stream.update("new_daily_meal_structure",
              partial: "daily_meal_structures/form",
              locals: { daily_meal_structure: DailyMealStructure.new })
          ]
        end
      end
    else
      @food_categories = FoodCategory.order(:description)
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("new_daily_meal_structure",
            partial: "daily_meal_structures/form",
            locals: { daily_meal_structure: @daily_meal_structure })
        end
      end
    end
  end

  def edit
    @food_categories = FoodCategory.order(:description)
  end

  def update
    if @daily_meal_structure.update(daily_meal_structure_params)
      respond_to do |format|
        format.html { redirect_to daily_meal_structures_path, notice: "Meal structure updated successfully." }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "daily_meal_structure_#{@daily_meal_structure.id}",
            partial: "daily_meal_structures/daily_meal_structure",
            locals: { daily_meal_structure: @daily_meal_structure }
          )
        end
      end
    else
      @food_categories = FoodCategory.order(:description)
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream
      end
    end
  end

  def destroy
    @daily_meal_structure.destroy

    respond_to do |format|
      format.html { redirect_to daily_meal_structures_path, notice: "Meal structure deleted successfully." }
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove("daily_meal_structure_#{@daily_meal_structure.id}")
      end
    end
  end

  def duplicate
    new_structure = @daily_meal_structure.dup
    new_structure.name = "#{@daily_meal_structure.name} (Copy)"

    @daily_meal_structure.meal_definitions.each do |meal_def|
      new_meal = new_structure.meal_definitions.build(
        label: meal_def.label,
        position: meal_def.position
      )

      meal_def.meal_definition_categories.each do |mdc|
        new_meal.meal_definition_categories.build(
          food_category_id: mdc.food_category_id,
          position: mdc.position
        )
      end
    end

    if new_structure.save
      redirect_to daily_meal_structures_path, notice: "Meal structure duplicated successfully."
    else
      redirect_to daily_meal_structures_path, alert: "Failed to duplicate meal structure."
    end
  end

  private

  def set_daily_meal_structure
    @daily_meal_structure = Current.user.daily_meal_structures.find(params[:id])
  end

  def daily_meal_structure_params
    params.require(:daily_meal_structure).permit(
      :name,
      meal_definitions_attributes: [
        :id,
        :label,
        :position,
        :_destroy,
        meal_definition_categories_attributes: [
          :id,
          :food_category_id,
          :position,
          :_destroy
        ]
      ]
    )
  end
end
