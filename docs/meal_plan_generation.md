# UX/Flow Brainstorming for Meal Plans

## Model Naming

I suggest GeneratedMealPlan for the AR model (or just MealPlan but with adjective to distinguish from the PORO PocDailyMealPlan). This name:
- Clearly indicates it's system-generated (not user-edited)
- Distinguishes from the PORO PocDailyMealPlan used by FlexibleMealComposer
- Future-proofs for potential EditedMealPlan or CustomMealPlan concepts

Alternative names: SavedMealPlan, ComposedMealPlan, SystemMealPlan

## UX Flow (Multi-Page, No Turbo)

1. Index Page (/meal_plans)

Similar to the other two index pages, show a table listing:

Table columns:
- Name - User-provided plan name
- Macro Target - Display the associated DailyMacroTarget name
- Meal Structure - Display the associated DailyMealStructure name
- Created - Timestamp
- Actions - View | Delete

Top of page:
- Header: "Meal Plans"
- Subtext: "Generate macro-precise meal plans using your targets and structures"
- Button: "Generate New Meal Plan" (goes to /meal_plans/new)

Empty state:
- Icon + "No meal plans yet"
- "Generate your first meal plan to get started"

---
2. New/Generation Page (/meal_plans/new)

Form fields:
1. Plan Name (text input, required)
  - Label: "Plan Name"
  - Placeholder: "e.g., Monday Keto Plan, High Protein Week"
2. Select Macro Target (dropdown/select, required)
  - Label: "Macro Target"
  - Options: User's DailyMacroTargets (show name + macros preview)
  - Example option: "Keto (25g carbs, 150g protein, 200g fat)"
  - Empty state: "You haven't created any macro targets yet. [Create one]"
3. Select Meal Structure (dropdown/select, required)
  - Label: "Meal Structure"
  - Options: User's DailyMealStructures (show name + meal count)
  - Example option: "Standard 3-Meal (3 meals)"
  - Empty state: "You haven't created any meal structures yet. [Create one]"

Submit button:
- "Generate Meal Plan" (primary CTA button)
- Maybe show a warning: "Generation may take 5-15 seconds"

Validation:
- Must have at least 1 macro target & 1 meal structure to render form
- If user has 0 of either, show helpful message with links to create them first

---
3. Show/Results Page (/meal_plans/:id)

After generation succeeds, redirect here to show the full plan:

Header:
- Plan name (h1)
- Metadata row:
  - "Using: [Macro Target Name] + [Meal Structure Name]"
  - "Generated on: [timestamp]"
  - Delete button (far right)

Macro Summary Card:
- Target vs Actual (side by side)
- Color-coded differences (green if within tolerance, yellow if close, red if way off)
- Show "Within tolerance" badge if applicable

Meal Cards (3 sections: Breakfast, Lunch, Dinner):
Each meal shows:
- Meal type header (Breakfast/Lunch/Dinner)
- List of foods with portions:
  - "125.0g of Chicken breast, skinless, boneless, raw"
  - "85.0g of Broccoli, raw"
  - "15.0g of Olive oil"
- Meal-level macros summary
  - "Carbs: 12g | Protein: 45g | Fat: 18g"

Actions at bottom:
- "Generate Another Plan" button (goes to /meal_plans/new)
- "Back to My Plans" link

---
Data Model Structure

GeneratedMealPlan (or MealPlan)

belongs_to :user
belongs_to :daily_macro_target
belongs_to :daily_meal_structure

has_many :generated_meals (or meal_plan_meals)

validates :name, presence: true, uniqueness: { scope: :user_id }

# Store computed values for quick display
target_carbs_grams (decimal)
target_protein_grams (decimal)
target_fat_grams (decimal)
actual_carbs_grams (decimal)
actual_protein_grams (decimal)
actual_fat_grams (decimal)
within_tolerance (boolean)

GeneratedMeal (or MealPlanMeal)

belongs_to :generated_meal_plan
has_many :generated_meal_foods (or meal_plan_food_portions)

meal_type (string: breakfast/lunch/dinner)
actual_carbs_grams (decimal)
actual_protein_grams (decimal)
actual_fat_grams (decimal)

GeneratedMealFood (or MealPlanFoodPortion)

belongs_to :generated_meal
belongs_to :food

grams (decimal, not null)

This mirrors the PORO structure but persists it to the database.

---
Controller Flow (MealPlansController or GeneratedMealPlansController)

new action:
- Load user's macro targets & meal structures
- Check if they have at least 1 of each (show error page if not)
- Render form

create action:
1. Validate params (name, macro_target_id, meal_structure_id)
2. Load the selected DailyMacroTarget & DailyMealStructure (scoped to current user)
3. Convert DailyMealStructure to the hash format FlexibleMealComposer expects
4. Call FlexibleMealComposer with converted data
5. If result.composed? == true:
  - Persist result to database (GeneratedMealPlan + associations)
  - Redirect to show page with success notice
6. If result.composed? == false:
  - Re-render new form with error: "Could not generate plan: #{result.error}"
  - Or maybe redirect back with alert

show action:
- Load meal plan (scoped to user, with includes for associations)
- Render detailed view

index action:
- Load all user's meal plans (order by created_at desc)
- Render table

destroy action:
- Find & destroy (dependent: :destroy handles cascades)
- Redirect to index with notice

---
Route Structure

resources :meal_plans, except: [:edit, :update]
# or
resources :generated_meal_plans, except: [:edit, :update]

No edit/update because these are fully system-generated. Delete is fine.

---
Performance Considerations

Synchronous First:
- Start with regular controller action
- If generation takes >5 seconds consistently, THEN switch to SolidQueue
- Could add a spinner/loading state on the form submission

If needed later (SolidQueue approach):
- Create action enqueues job, redirects to index with "Plan is generating..."
- Add status column to model (pending/completed/failed)
- Use polling or Action Cable to update when done
- Show "In Progress" badge in index table

---
Edge Cases to Handle

1. User deletes a macro target or meal structure that a plan depends on:
  - Use dependent: :nullify or keep the foreign keys but handle gracefully in views
  - Or prevent deletion if used by any plans (add validation)
2. FlexibleMealComposer fails (can't find solution):
  - Show friendly error message
  - Suggest trying different macro targets or meal structures
  - Maybe log failure reason for debugging
3. User has no macro targets or meal structures:
  - New page shows helpful message: "Before generating a plan, you need to create at least one macro target and one meal structure"
  - Provide direct links to create them
4. Food data changes after plan generation:
  - Plans are snapshots in time (stored grams + food_id)
  - If food is deleted from DB, handle gracefully (show "Food no longer available")

---
Visual Design Consistency

Match the existing pattern:
- Macro Targets index: Form on same page (turbo frame)
- Meal Structures index: Separate new page
- Meal Plans index: I'd lean toward separate new page (like meal structures) since generation is more complex

Keep Tailwind styling consistent with existing pages.

---
Summary

Model name: GeneratedMealPlan (or MealPlan)

Flow:
1. Index → table of plans + "Generate New" button
2. New → form with name + 2 dropdowns (macro target, meal structure)
3. Create → call FlexibleMealComposer → persist results → redirect to show
4. Show → display full plan with foods/grams/macros
5. Delete → remove plan

Start synchronous, measure performance, add SolidQueue if needed.

## Model Naming

Here are the model names that would be ideal for ActiveRecord but are currently occupied by proof-of-concept POROs:

  1. PocDailyMealPlan - POC PORO (wraps breakfast/lunch/dinner + target/actual macros)
  2. PocMeal - POC PORO (wraps food_portions array + macros)
  3. PocFoodPortion - POC PORO (wraps food + grams)
  4. MacroTargets - Currently a PORO (though we have DailyMacroTarget as AR, so less of an issue)

  **NOTE**: The POC POROs have been renamed with "Poc" prefix, freeing up DailyMealPlan, Meal, and FoodPortion as intuitive names for the persisted AR models.
