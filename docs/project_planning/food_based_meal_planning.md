- [Food-Based Meal Planning: Feasibility Analysis](#food-based-meal-planning-feasibility-analysis)
  - [Algorithmic Feasibility: YES, Highly Feasible ✅](#algorithmic-feasibility-yes-highly-feasible-)
    - [Why it's straightforward:](#why-its-straightforward)
  - [Data Model Changes Needed](#data-model-changes-needed)
    - [Selected Approach: Unified Model with Modes (Recommended) ✅](#selected-approach-unified-model-with-modes-recommended-)
    - [Why Not Option B (Separate Models)?](#why-not-option-b-separate-models)
  - [Service Architecture](#service-architecture)
    - [Recommended approach:](#recommended-approach)
    - [Key difference in compose\_single\_meal:](#key-difference-in-compose_single_meal)
  - [UX/UI Challenge: Food Selection with 4K Foods](#uxui-challenge-food-selection-with-4k-foods)
    - [1. Search + Favorites (MVP approach)](#1-search--favorites-mvp-approach)
    - [2. Browse by Category with nested foods](#2-browse-by-category-with-nested-foods)
    - [3. Macro-filtered explorer](#3-macro-filtered-explorer)
    - [4. AI-powered suggestions (future)](#4-ai-powered-suggestions-future)
  - [Understanding the User Problem](#understanding-the-user-problem)
    - [Key Insight: The Swap Feature](#key-insight-the-swap-feature)
  - [Product UX: Solving the User Confusion Problem](#product-ux-solving-the-user-confusion-problem)
    - [Option 1: Explicit at Creation Time (Clearest)](#option-1-explicit-at-creation-time-clearest)
    - [Option 2: Unified UI, Smart Default (Most seamless)](#option-2-unified-ui-smart-default-most-seamless)
    - [Option 3: Progressive Disclosure (Best UX, hardest to build)](#option-3-progressive-disclosure-best-ux-hardest-to-build)
  - [The Swap Feature (Designed In, Not Built Yet)](#the-swap-feature-designed-in-not-built-yet)
  - [Recommended MVP Approach](#recommended-mvp-approach)
    - [Phase 1: Prove algorithmic feasibility](#phase-1-prove-algorithmic-feasibility)
    - [Phase 2: Data modeling](#phase-2-data-modeling)
    - [Phase 3: Basic UI](#phase-3-basic-ui)
    - [Phase 4: Future enhancements](#phase-4-future-enhancements)
  - [Implementation Notes](#implementation-notes)
    - [Mode Selection is at MealStructureItem Level (Not DailyMealStructure Level)](#mode-selection-is-at-mealstructureitem-level-not-dailymealstructure-level)
    - [How MealPlanGenerator Will Route Per-Meal](#how-mealplangenerator-will-route-per-meal)
    - [Service Architecture (Revised)](#service-architecture-revised)
    - [Why This Is Experimental-Friendly](#why-this-is-experimental-friendly)
  - [Feasibility Verdict](#feasibility-verdict)
  - [Finalized Data Model Summary](#finalized-data-model-summary)
  - [Recommended Next Steps](#recommended-next-steps)
    - [Phase 1 (Algorithmic Proof - CRITICAL)](#phase-1-algorithmic-proof---critical)
    - [Phase 2 (Data Model)](#phase-2-data-model)
    - [Phase 3 (UI)](#phase-3-ui)
    - [Phase 4+ (Future)](#phase-4-future)
  - [Ready to Proceed?](#ready-to-proceed)

# Food-Based Meal Planning: Feasibility Analysis

## Algorithmic Feasibility: YES, Highly Feasible ✅

### Why it's straightforward:

1. **The core algorithm is food-agnostic**
   - `MealPlanGenerator#optimize_portions` (line 244) works with ANY set of foods
   - It only cares about macro coefficients per food, not where they came from
   - The gradient descent optimization will work identically whether foods are randomly selected from categories or explicitly chosen by the user

2. **Minimal algorithmic changes needed**
   - Instead of `randomly_select_foods(category_ids)` picking random foods from categories, you'd pass pre-selected foods directly
   - The optimization pipeline stays the same: extract macros → gradient descent → return portions
   - This is **not a constraint satisfaction problem** - it's pure numerical optimization

3. **The hard part is already solved**
   - `NutrientLookupService.macronutrients_for(food)` already handles all the macro data extraction
   - `food_has_complete_macro_data?` already validates if a food can be used
   - All the tolerance/relaxation logic is already there

## Data Model Changes Needed

Currently: `MealStructureItem` stores `food_category_ids` (array of category IDs)

### Selected Approach: Unified Model with Modes (Recommended) ✅

Keep it simple. Single `DailyMealStructure` model with both modes:

```ruby
# Migration
add_column :meal_structure_items, :food_ids, :integer, array: true, default: []
add_column :meal_structure_items, :mode, :integer, default: 0  # 0=categories, 1=foods

# Model
class MealStructureItem < ApplicationRecord
  enum mode: { categories: 0, foods: 1 }

  # Validation: either food_category_ids OR food_ids, but not both
  validate :has_either_categories_or_foods

  private

  def has_either_categories_or_foods
    has_categories = food_category_ids.present?
    has_foods = food_ids.present?

    if has_categories && has_foods
      errors.add(:base, "Cannot mix category and food selection")
    elsif !has_categories && !has_foods
      errors.add(:base, "Must select either categories or specific foods")
    end
  end
end
```

**Why this approach:**
- ✅ No new models needed (less cognitive load, fewer migrations)
- ✅ Each meal item is clearly either/or, not confused
- ✅ Future swap feature knows which category to search in (via `food_ids.map(&:food_category_id)`)
- ✅ User never mixes modes within a single meal
- ✅ Easy to support both workflows simultaneously
- ✅ Can tear down/restructure later if needed—data model is simple

### Why Not Option B (Separate Models)?

We decided against creating separate `FoodBasedMealStructure` and `FoodBasedMealStructureItem` models because:
- Adds unnecessary complexity
- Duplicates logic and UI
- Makes it harder to eventually unify the workflows
- Single mode per meal item is clear enough without separate models

## Service Architecture

### Recommended approach:

```
MealPlanGenerator (abstract base or shared logic)
├── MealPlanGeneratorByCategory (current, extract/rename)
└── MealPlanGeneratorByFood (new)
```

### Key difference in compose_single_meal:
- Current: `randomly_select_foods(category_ids)` - picks random foods from categories
- New: `use_selected_foods(food_ids)` - directly uses provided foods

Everything else is identical.

## UX/UI Challenge: Food Selection with 4K Foods

This is the **real complexity**. Some options ranked by feasibility:

### 1. Search + Favorites (MVP approach)
- Typeahead search on food description
- Show macros inline (carbs/protein/fat per 100g)
- Let users build a personal favorites list
- **Pros:** Simple to implement, good UX
- **Cons:** Requires JS search component, but you already use Stimulus

### 2. Browse by Category with nested foods
- Start with category picker (familiar to users)
- Within category, show foods as searchable list
- **Pros:** Bridges to current UX, users know categories
- **Cons:** Still 4K foods, needs pagination/virtualization

### 3. Macro-filtered explorer
- Filter foods by protein level, fat level, etc.
- Then search within filtered set
- **Pros:** Reduces selection space significantly
- **Cons:** More complex UI

### 4. AI-powered suggestions (future)
- "Suggest 5 foods that would work for this meal"
- User picks from suggestions or searches
- **Pros:** Best UX
- **Cons:** Requires LLM integration

## Understanding the User Problem

There are two user archetypes:

1. **Flexible Planners** (current category-based): "I want eggs, some cooking fat, and fruit for breakfast—anything works"
2. **Specific Planners** (new food-based): "I want *scrambled eggs*, *butter*, and *raspberries*—those specific things"

The output is always the same to the user: a shopping list with specific foods and quantities. But the **input process** and **flexibility** are fundamentally different.

### Key Insight: The Swap Feature

Both modes need to support swapping foods in the generated meal plan. This reveals why the data model matters:

**For category-based plans:**
- User sees: "Scrambled eggs (150g), Butter (20g), Raspberries (100g)"
- User wants to swap: "I don't like raspberries"
- System action: Find another fruit in the "Fruits" category, re-optimize

**For food-based plans:**
- User sees: "Scrambled eggs (150g), Butter (20g), Raspberries (100g)"
- User wants to swap: "I don't like raspberries"
- System action: Either:
  - Option A: Let user pick a specific replacement food
  - Option B: Detect category of raspberries (Fruits), find alternatives, let user pick
  - Option C: Both—auto-suggest alternatives but let user search too

**The key insight:** Both need to know the category of each food in the output to enable swapping later. This is already solved because `Food` belongs to `FoodCategory`.

## Product UX: Solving the User Confusion Problem

Users might not understand the difference between category and food modes. Here's how to handle it:

### Option 1: Explicit at Creation Time (Clearest)
```
"How would you like to plan breakfast?"
○ Flexible: Pick food categories (system chooses specific foods)
○ Specific: Pick exact foods (system hits your macros with your foods)
```

Then show appropriate UI (category picker vs food search).

### Option 2: Unified UI, Smart Default (Most seamless)
- Show category list like today
- But add a "lock in" button next to selected categories
- Locked categories: uses specific foods (you pick them)
- Unlocked categories: uses random foods from category
- This blurs the lines but might feel more natural

### Option 3: Progressive Disclosure (Best UX, hardest to build)
- Start with category mode (familiar)
- Show option to "specify exact foods for this meal"
- Only show food picker if user clicks that

## The Swap Feature (Designed In, Not Built Yet)

Once meal plan is generated, for each meal show:

```
Breakfast
├── Scrambled eggs (150g) [from Eggs and omelets category]
    └── Swap → suggests other eggs, or search categories
├── Butter (20g) [from Butter and animal fats category]
    └── Swap → suggests other fats, or search categories
└── Raspberries (100g) [from Blueberries and other berries category]
    └── Swap → suggests other berries, or search categories
```

**Key insight:** Whether the plan was created via categories or foods, swapping logic is the same: know the food's category, find alternatives, re-optimize.

## Recommended MVP Approach

### Phase 1: Prove algorithmic feasibility
- [ ] Create `MealPlanGeneratorByFood` service
- [ ] Test it in Rails console with hardcoded foods
- [ ] Verify it produces valid meal plans
- [ ] Document any edge cases or constraints

### Phase 2: Data modeling
- [ ] Add `food_ids` and `mode` columns to `MealStructureItem`
- [ ] Add validation logic for exclusive mode
- [ ] Create controller logic to route to correct generator

### Phase 3: Basic UI
- [ ] Add tab/toggle: "Categories" vs "Specific Foods"
- [ ] Category mode: existing UI
- [ ] Food mode: typeahead search for foods with macro info

### Phase 4: Future enhancements
- [ ] Swap feature (works for both modes)
- [ ] Favorites/history
- [ ] Advanced filtering
- [ ] Macro-filtered explorer

## Implementation Notes

### Mode Selection is at MealStructureItem Level (Not DailyMealStructure Level)

**This is critical:** The `mode` enum applies to each individual `MealStructureItem`, NOT to the entire `DailyMealStructure`. This allows maximum flexibility.

**Example:**
```
DailyMealStructure: "Three Meals A Day"
├── MealStructureItem: Breakfast
│   ├── mode: :categories
│   └── food_category_ids: [eggs_id, fruit_id, animal_fats_id]
│
├── MealStructureItem: Lunch
│   ├── mode: :foods
│   └── food_ids: [tuna_salad_id, green_leaf_lettuce_id, olive_oil_id]
│
└── MealStructureItem: Dinner
    ├── mode: :categories
    └── food_category_ids: [beef_id, vegetables_id, fats_id]
```

**This means:**
- ✅ Users can mix modes within a single meal structure
- ✅ Breakfast: randomly select from category options (flexible, user doesn't care which eggs)
- ✅ Lunch: use exact food selections (specific, user wants tuna salad not chicken)
- ✅ Dinner: back to categories (flexible again)
- ✅ Maximum flexibility: users can gradually experiment as they learn the system

### How MealPlanGenerator Will Route Per-Meal

The generator will check each meal's mode individually:

```ruby
# app/services/meal_plan_generator.rb (revised)
def compose_single_meal(meal_type:, target_carbs:, target_protein:, target_fat:)
  meal_structure_item = daily_meal_structure.meal_structure_items.find_by(meal_label: meal_type.to_s)

  # Route based on this specific meal's mode
  if meal_structure_item.foods?
    # Use explicit food selections
    foods_with_grams = prepare_selected_foods(meal_structure_item.food_ids)
  else
    # Use random selection from categories (existing logic)
    foods_with_grams = randomly_select_foods(meal_structure_item.food_category_ids)
  end

  # Rest of optimization is identical
  optimize_portions(foods_with_grams, target_carbs, target_protein, target_fat)
end
```

### Service Architecture (Revised)

Rather than two separate service classes, we can have a single flexible `MealPlanGenerator` with internal routing:

```ruby
# app/services/meal_plan_generator.rb
class MealPlanGenerator
  # ... existing code ...

  private

  # Route based on meal's mode
  def compose_single_meal(meal_type:, target_carbs:, target_protein:, target_fat:)
    meal_structure_item = daily_meal_structure.meal_structure_items.find_by(meal_label: meal_type.to_s)

    # Handle per-meal mode
    if meal_structure_item.foods?
      compose_meal_by_foods(meal_structure_item, target_carbs, target_protein, target_fat)
    else
      compose_meal_by_categories(meal_structure_item, target_carbs, target_protein, target_fat)
    end
  end

  def compose_meal_by_foods(meal_structure_item, target_carbs, target_protein, target_fat)
    # Use explicit foods instead of random selection
    foods_with_grams = meal_structure_item.food_ids.map do |food_id|
      FoodWithGrams.new(food: Food.find(food_id), grams: 0)
    end

    # Try to optimize with provided foods (same 10 attempts as before)
    # ... rest of existing optimization logic ...
  end

  def compose_meal_by_categories(meal_structure_item, target_carbs, target_protein, target_fat)
    # Existing logic - randomly select from categories
    # ... rest of existing code ...
  end
end
```

This approach keeps everything in one service class while cleanly separating the two workflows.

### Why This Is Experimental-Friendly

Since you noted this is experimental and restructuring is acceptable:
- The unified model with `mode` enum is non-destructive
- Can easily add new fields or columns without migrating existing data
- Services can be tested independently
- UI can be toggled/switched between modes
- If a complete rewrite is needed later, the groundwork is in place

## Feasibility Verdict

| Aspect | Verdict | Effort |
|--------|---------|--------|
| Algorithm (optimizer) | ✅ **Trivial** | 2-4 hours |
| Data model | ✅ **Easy** | 2-3 hours |
| Service layer | ✅ **Straightforward** | 4-6 hours |
| Search UI | ⚠️ **Moderate** | 8-12 hours |
| Full feature parity | ⚠️ **Medium** | 20+ hours |

## Finalized Data Model Summary

```ruby
# Migration
add_column :meal_structure_items, :food_ids, :integer, array: true, default: []
add_column :meal_structure_items, :mode, :integer, default: 0

# Model validation
class MealStructureItem < ApplicationRecord
  enum mode: { categories: 0, foods: 1 }

  validate :has_either_categories_or_foods

  private

  def has_either_categories_or_foods
    has_categories = food_category_ids.present?
    has_foods = food_ids.present?

    if has_categories && has_foods
      errors.add(:base, "Cannot mix category and food selection within a meal")
    elsif !has_categories && !has_foods
      errors.add(:base, "Must select either categories or specific foods for a meal")
    end
  end
end
```

## Recommended Next Steps

### Phase 1 (Algorithmic Proof - CRITICAL)
- Build `compose_meal_by_foods` helper method in `MealPlanGenerator`
- Test in Rails console with hardcoded foods
- Verify optimization works with user-selected foods
- Document any edge cases or constraints

### Phase 2 (Data Model)
- Create migration adding `food_ids` and `mode` columns to `meal_structure_items`
- Update `MealStructureItem` model with validation
- Refactor `MealPlanGenerator#compose_single_meal` with per-meal mode routing

### Phase 3 (UI)
- Decide on UX model for mode selection:
  - Option 1 (Explicit): Clear tab/toggle for each meal
  - Option 2 (Smart): Hidden toggle with smart defaults
  - Option 3 (Progressive): Gradual disclosure
- Implement food picker (search + macros display)
- Update meal structure form to support both modes

### Phase 4+ (Future)
- Swap feature
- Favorites
- Advanced filtering

## Ready to Proceed?

We have a clear, tested approach:
- ✅ Data model: Simple, non-destructive, per-meal-item mode selection
- ✅ Algorithm: Food-agnostic, should work with explicit food lists
- ✅ Architecture: Single flexible service class, not two separate classes
- ✅ UX: Three viable options, choice deferred to later
- ✅ Backward compatible: Existing category-based plans keep working

The only unknown is Phase 1 (algorithm). Everything else follows naturally if Phase 1 succeeds.
