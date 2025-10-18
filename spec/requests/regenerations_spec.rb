require "rails_helper"

RSpec.describe "Regenerations", type: :request do
  let(:user) { create(:user) }
  let(:macro_target) { create(:daily_macro_target, user: user) }
  let(:meal_structure) { create(:daily_meal_structure, user: user) }
  let(:meal_plan) { create(:daily_meal_plan, user: user, daily_macro_target: macro_target, daily_meal_structure: meal_structure) }

  before do
    sign_in user
  end

  describe "POST /meal_plans/:meal_plan_id/regenerations" do
    context "when regeneration succeeds" do
      it "replaces the existing meals with newly generated ones" do
        # Create initial meals
        breakfast = create(:meal, daily_meal_plan: meal_plan, meal_type: :breakfast)
        lunch = create(:meal, daily_meal_plan: meal_plan, meal_type: :lunch)
        dinner = create(:meal, daily_meal_plan: meal_plan, meal_type: :dinner)

        original_meal_count = meal_plan.meals.count
        expect(original_meal_count).to eq(3)

        post meal_plan_regenerations_path(meal_plan)

        expect(response).to redirect_to(meal_plan_path(meal_plan))
        follow_redirect!
        expect(response.body).to include("regenerated successfully")
      end

      it "updates the meal plan's actual macros" do
        post meal_plan_regenerations_path(meal_plan)

        meal_plan.reload
        expect(meal_plan.actual_carbs_grams).to be_present
        expect(meal_plan.actual_protein_grams).to be_present
        expect(meal_plan.actual_fat_grams).to be_present
      end

      it "preserves the meal plan's name and relationships" do
        original_name = meal_plan.name
        original_macro_target_id = meal_plan.daily_macro_target_id
        original_meal_structure_id = meal_plan.daily_meal_structure_id

        post meal_plan_regenerations_path(meal_plan)

        meal_plan.reload
        expect(meal_plan.name).to eq(original_name)
        expect(meal_plan.daily_macro_target_id).to eq(original_macro_target_id)
        expect(meal_plan.daily_meal_structure_id).to eq(original_meal_structure_id)
      end
    end

    context "when regeneration fails" do
      it "redirects with an error message" do
        allow_any_instance_of(MealPlanGenerator).to receive(:generate).and_return(
          double(success?: false, error: "Unable to generate meal plan")
        )

        post meal_plan_regenerations_path(meal_plan)

        expect(response).to redirect_to(meal_plan_path(meal_plan))
        follow_redirect!
        expect(response.body).to include("Could not regenerate plan")
      end
    end

    context "when user is not authenticated" do
      before do
        sign_out user
      end

      it "redirects to login" do
        post meal_plan_regenerations_path(meal_plan)
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "when accessing another user's meal plan" do
      let(:other_user) { create(:user) }
      let(:other_user_meal_plan) { create(:daily_meal_plan, user: other_user) }

      it "raises RecordNotFound" do
        expect {
          post meal_plan_regenerations_path(other_user_meal_plan)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
