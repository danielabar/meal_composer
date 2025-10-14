class MealPlansController < ApplicationController
  before_action :require_authentication
  before_action :set_meal_plan, only: [ :show, :destroy ]

  def index
    @meal_plans = Current.user.daily_meal_plans
      .includes(:daily_macro_target, :daily_meal_structure)
      .order(created_at: :desc)
  end

  def new
    @macro_targets = Current.user.daily_macro_targets.order(:name)
    @meal_structures = Current.user.daily_meal_structures.order(:name)
    @meal_plan = DailyMealPlan.new
  end

  def create
    # Find the selected macro target and meal structure
    macro_target = Current.user.daily_macro_targets.find(params[:daily_meal_plan][:daily_macro_target_id])
    meal_structure = Current.user.daily_meal_structures.find(params[:daily_meal_plan][:daily_meal_structure_id])

    # Generate the meal plan using the service
    generator = MealPlanGenerator.new(
      user: Current.user,
      name: params[:daily_meal_plan][:name],
      daily_macro_target: macro_target,
      daily_meal_structure: meal_structure
    )

    result = generator.generate

    if result.success?
      redirect_to meal_plan_path(result.daily_meal_plan), notice: "Meal plan generated successfully!"
    else
      flash.now[:alert] = "Could not generate plan: #{result.error}"
      @macro_targets = Current.user.daily_macro_targets.order(:name)
      @meal_structures = Current.user.daily_meal_structures.order(:name)
      @meal_plan = DailyMealPlan.new(name: params[:daily_meal_plan][:name])
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    flash.now[:alert] = "Invalid macro target or meal structure selected."
    @macro_targets = Current.user.daily_macro_targets.order(:name)
    @meal_structures = Current.user.daily_meal_structures.order(:name)
    @meal_plan = DailyMealPlan.new(name: params[:daily_meal_plan][:name])
    render :new, status: :unprocessable_entity
  end

  def show
    @meal_plan = Current.user.daily_meal_plans
      .includes(meals: { food_portions: :food })
      .find(params[:id])
  end

  def destroy
    @meal_plan.destroy
    redirect_to meal_plans_path, notice: "Meal plan deleted successfully."
  end

  private

  def set_meal_plan
    @meal_plan = Current.user.daily_meal_plans.find(params[:id])
  end
end
