class DailyMacroTargetsController < ApplicationController
  before_action :require_authentication
  before_action :set_daily_macro_target, only: [ :edit, :update, :destroy ]

  def index
    @daily_macro_targets = Current.user.daily_macro_targets.order(created_at: :desc)
    @daily_macro_target = DailyMacroTarget.new
  end

  def create
    @daily_macro_target = Current.user.daily_macro_targets.build(daily_macro_target_params)

    if @daily_macro_target.save
      redirect_to daily_macro_targets_path, notice: "Macro target was successfully created."
    else
      @daily_macro_targets = Current.user.daily_macro_targets.order(created_at: :desc)
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @daily_macro_target.update(daily_macro_target_params)
      redirect_to daily_macro_targets_path, notice: "Macro target was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @daily_macro_target.destroy
    redirect_to daily_macro_targets_path, notice: "Macro target was successfully deleted."
  end

  private

  def set_daily_macro_target
    @daily_macro_target = Current.user.daily_macro_targets.find(params[:id])
  end

  def daily_macro_target_params
    params.require(:daily_macro_target).permit(:name, :carbs_grams, :protein_grams, :fat_grams)
  end
end
