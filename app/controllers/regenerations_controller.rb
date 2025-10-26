class RegenerationsController < ApplicationController
  before_action :require_authentication
  before_action :set_meal_plan

  def create
    # Compose new meals using the same macro target and meal structure
    generator = MealPlanGenerator.new(
      user: Current.user,
      name: @meal_plan.name,
      daily_macro_target: @meal_plan.daily_macro_target,
      daily_meal_structure: @meal_plan.daily_meal_structure
    )

    composition_result = generator.compose_meals

    if composition_result.nil?
      # Get the detailed failure message from the generator
      error_msg = generator.instance_variable_get(:@failure_message) || "Unable to compose meals"
      redirect_to meal_plan_path(@meal_plan), alert: "Could not regenerate plan: #{error_msg}"
      return
    end

    # Update the meal plan with new composition
    ActiveRecord::Base.transaction do
      # Clear existing meals
      @meal_plan.meals.destroy_all

      # Create new meals from composition
      composition_result[:composed_meals].each do |meal_type, meal_data|
        meal = @meal_plan.meals.create!(
          meal_type: meal_type.to_s,
          actual_carbs_grams: meal_data[:actual_carbs],
          actual_protein_grams: meal_data[:actual_protein],
          actual_fat_grams: meal_data[:actual_fat]
        )

        # Create food portions for this meal
        meal_data[:foods_with_grams].each do |item|
          meal.food_portions.create!(
            food_id: item.food.id,
            grams: item.grams
          )
        end
      end

      # Update the daily meal plan's actual macros
      @meal_plan.update!(
        actual_carbs_grams: composition_result[:actual_carbs],
        actual_protein_grams: composition_result[:actual_protein],
        actual_fat_grams: composition_result[:actual_fat]
      )
    end

    redirect_to meal_plan_path(@meal_plan), notice: "Meal plan regenerated successfully!"
  rescue StandardError => e
    Rails.logger.error("Regeneration failed: #{e.message}")
    redirect_to meal_plan_path(@meal_plan), alert: "Could not regenerate plan: #{e.message}"
  end

  private

  def set_meal_plan
    @meal_plan = Current.user.daily_meal_plans.find(params[:meal_plan_id])
  end
end
