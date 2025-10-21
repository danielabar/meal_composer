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
    # Build a map of all food IDs to their names for hydrating the edit view
    # This is used by the food_selector Stimulus controller to display food names
    @food_id_to_name_map = build_food_id_to_name_map(@daily_meal_structure)
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

  def build_food_id_to_name_map(daily_meal_structure)
    # Collect all food IDs from all meal structure items
    all_food_ids = daily_meal_structure.meal_structure_items.flat_map(&:food_ids).compact.uniq

    # Fetch the foods and build a map
    foods = Food.where(id: all_food_ids)
    foods.index_by(&:id).transform_values(&:description)
  end

  def daily_meal_structure_params
    params.require(:daily_meal_structure).permit(
      :name,
      meal_structure_items_attributes: [
        :id,
        :meal_label,
        :position,
        :mode,
        :_destroy,
        food_category_ids: [],
        food_ids: []
      ]
    ).tap do |allowed|
      # Clean up empty arrays based on mode
      allowed[:meal_structure_items_attributes]&.each do |_index, attrs|
        next unless attrs.is_a?(Hash)

        case attrs[:mode]
        when "food"
          attrs.delete(:food_category_ids)
        else
          # Default to category mode
          attrs[:mode] = "category" if attrs[:mode].blank?
          attrs.delete(:food_ids)
        end
      end
    end
  end
end
