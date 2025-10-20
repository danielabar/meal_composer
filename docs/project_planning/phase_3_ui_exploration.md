# Phase 3: UI/UX Exploration - Current Meal Structure Form

## Current State: Category-Based Only

The meal structure form currently supports **only category-based meal planning**. Here's how it works:

### Current Flow

1. **Meal Structure Creation** (`/daily_meal_structures/new`)
   - User names the meal structure (e.g., "Three Meals A Day")
   - Pre-populated with 3 default meals: Breakfast, Lunch, Dinner

2. **Per-Meal Configuration**
   - **Meal Type**: Dropdown selector (Breakfast, Brunch, Lunch, Dinner, Snack)
   - **Order**: Position number for meal sequence
   - **Food Categories**: Checkbox grid showing ~150 FNDDS food categories
     - Categories displayed in 3-column grid layout
     - Scrollable (max-height: 384px)
     - Live "selected count" badge at top
     - Live tag display of selected categories

3. **Form Features**
   - "Add Another Meal" button to add more meals dynamically
   - "Remove" button per meal (soft delete via `_destroy` field)
   - Stimulus controllers handle all interactions:
     - `meal_structure_form_controller.js` - Add/remove meals
     - `category_selector_controller.js` - Track selected categories, display tags

### Current Architecture

**Controller** (`app/controllers/daily_meal_structures_controller.rb`)
- Permits: `food_category_ids: []` (array of category IDs)
- Pre-builds 3 meal items in `new` action
- No support for `mode` or `food_ids` yet

**Model** (`app/models/meal_structure_item.rb`)
- Has new `mode` and `food_ids` columns from migration
- But form doesn't use them yet
- Validation logic is in place but not tested in UI

**View** (`app/views/daily_meal_structures/_meal_structure_item_fields.html.erb`)
- Only renders `food_category_ids` checkboxes
- No way to toggle between modes
- No food search/selection UI

---

## What Needs to Change for Phase 3

### Key Decisions Before Implementation

**Decision 1: When/How to Select Mode?**

Three options from planning doc:

**Option A: Explicit Mode Tab/Toggle (Clearest)**
- Add tab/toggle control in meal-item header
- Clicking "Categories" shows category checkboxes (current UI)
- Clicking "Specific Foods" shows food search UI
- Pros: Crystal clear to users
- Cons: More UI real estate, requires two separate sections

**Option B: Smart Default with Toggle (Seamless)**
- Default to category mode (familiar)
- Add subtle "Switch to Specific Foods" link/button
- Only show food picker if user clicks
- Pros: Gradual discovery, less overwhelming
- Cons: Users might not realize the option exists

**Option C: Progressive Disclosure (Best UX, Hardest)**
- Start with category mode
- After selecting categories, show "Lock in these food picks?" button
- If clicked, becomes food-based mode with specific foods
- Pros: Most intuitive progression
- Cons: Requires modal/workflow redesign

### Implementation Scope for Each Mode

#### If User Selects Category Mode (Current)
- Keep existing category checkbox grid
- Validates: at least one category selected

#### If User Selects Food Mode (New)
- Show food search interface instead
- Key challenge: **How to handle 4K foods?**

**Food Picker Options:**

**Approach 1: Typeahead Search (MVP)**
- Text input with autocomplete
- Shows: "Chicken, whole pieces (100g serving: 31C, 25P, 1F)"
- User types, results filter in real-time
- Selected foods show as tags (like categories do now)
- Pros: Works with large dataset, familiar pattern
- Cons: Requires server-side search endpoint

**Approach 2: Category Filter + Search**
- First: User picks category (dropdown)
- Then: Foods within that category appear
- Filter by protein/carb/fat level
- Search within filtered list
- Pros: Reduces cognitive load, familiar structure
- Cons: More steps, slightly more complex

**Approach 3: AI Suggestions + Search**
- "Suggest foods for this meal" button
- Returns 5-10 suggestions based on macro targets
- User picks from suggestions or searches for alternatives
- Pros: Best UX, smart
- Cons: Requires API integration, more work

---

## Current Form Technical Details

### HTML Structure

```html
<div class="meal-item" data-controller="category-selector">
  <!-- Meal Type + Order (2-column grid) -->
  <select name="meal_label"> ... </select>
  <input type="number" name="position"> ... </input>

  <!-- Food Categories Section -->
  <div class="selected-display"> ... </div>
  <div class="checkbox-grid">
    <!-- ~150 food category checkboxes -->
  </div>
</div>
```

### Form Fields (Currently Permitting)

```ruby
meal_structure_items_attributes: [
  :id,
  :meal_label,
  :position,
  :_destroy,
  food_category_ids: []    # <-- Only this is used
]
```

**Need to add:**
```ruby
:mode,                       # "category" or "food"
food_ids: []                 # Array of food IDs (for food-based mode)
```

### Stimulus Controllers

**meal_structure_form_controller.js**
- Manages: Add/remove meal items
- Uses: Cloning template with unique timestamp
- Handles: Soft delete via `_destroy` field

**category_selector_controller.js**
- Manages: Category selection state
- Tracks: Selected categories, count, tag display
- Updates: Live badge showing "Selected (3):"
- Scope: Per meal item (scoped to `data-controller="category-selector"`)

---

## Mock-Up of Mode Toggle (Option A)

```
┌─────────────────────────────────────────────────────────┐
│ Breakfast                                         [Remove]│
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Mode: [● Categories]  [○ Specific Foods]              │
│                                                          │
│  Meal Type: [Breakfast ▼]    Order: [0]                │
│                                                          │
│  When "Categories" selected:                           │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Selected (2):                                   │   │
│  │ [Eggs and omelets] [Blueberries and...] [x]   │   │
│  ├─────────────────────────────────────────────────┤   │
│  │ ☑ Eggs and omelets                              │   │
│  │ ☐ Apples                                        │   │
│  │ ☑ Blueberries and other berries                │   │
│  │ ☐ Bacon                                         │   │
│  │ ... (scrollable)                                │   │
│  └─────────────────────────────────────────────────┘   │
│                                                          │
│  When "Specific Foods" selected:                       │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Selected (2):                                   │   │
│  │ [Scrambled eggs...] [Raspberries, raw] [x]    │   │
│  ├─────────────────────────────────────────────────┤   │
│  │ Search foods... [________] [Search]            │   │
│  │                                                 │   │
│  │ Results (showing macros per 100g):              │   │
│  │ ☑ Eggs, scrambled (13g C, 11g P, 11g F)       │   │
│  │ ☐ Eggs, fried (5g C, 13g P, 11g F)            │   │
│  │ ☑ Raspberries, raw (12g C, 1g P, 1g F)        │   │
│  │ ... (scrollable)                                │   │
│  └─────────────────────────────────────────────────┘   │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## Testing Considerations

### When User Saves with Food-Based Mode

1. Validation should:
   - Require `mode` to be "category" or "food"
   - If mode="category": require ≥1 category
   - If mode="food": require ≥1 food

2. Controller should:
   - Accept both `food_category_ids` and `food_ids` in params
   - Only one should have values (enforced by model validation)

3. MealPlanGenerator should:
   - Check `meal_structure_item.mode`
   - Route to `compose_meal_by_foods` or `compose_meal_by_categories`

---

## Next Steps

### Before Building Phase 3 UI:

1. **Decide on Mode Selection UX** (Option A/B/C)
2. **Decide on Food Picker Approach** (Typeahead/Category Filter/AI)
3. **Update Controller** to permit `mode` and `food_ids`
4. **Build Food Search Endpoint** (if using typeahead)
5. **Update Form View** with mode toggle + food picker
6. **Update Stimulus Controllers** to handle both modes

### Recommended Order:

1. **Option A** (Explicit mode toggle) - clearest for users
2. **Approach 1** (Typeahead search) - MVP-compatible, minimal backend work
3. Focus on single-meal first, then multi-meal

This keeps complexity manageable while giving users maximum control.

---

## Phase 3B: Food Search UI Implementation (PAUSED - AWAITING DECISIONS)

**Status:** Implementation paused. The per-meal mode toggle is complete with "Coming Soon" placeholder. Before building the food search UI, these decisions must be made:

### Implementation Status

✅ **Completed:**
- Per-meal mode toggle (radio buttons: "Categories" vs "Specific Foods")
- Mode-aware validation in MealStructureItem model
- Controller parameter cleanup based on mode
- Stimulus controller for toggling visibility between sections
- "Coming Soon" placeholder message for foods mode

🚀 **Next Phase:** Build the food search/autocomplete UI for foods mode

### Design Decisions Required (MUST ANSWER BEFORE PROCEEDING)

**Question 1: Search Trigger**
When should the autocomplete dropdown appear?
- A) Only when user types (≥2 characters)?
- B) When they click the input (show recent/all foods)?
- C) Both?

**Question 2: Food Info Display in Dropdown**
What should each food result show?
- Option A: Just name: `"Scrambled eggs"`
- Option B: With macros: `"Scrambled eggs (13g C, 11g P, 11g F per 100g)"`
- Option C: With category: `"Scrambled eggs - Eggs and omelets"`
- Option D: All three: `"Scrambled eggs - Eggs and omelets (13g C, 11g P, 11g F per 100g)"`

**Question 3: Selection Limits**
What are the practical min/max foods per meal?
- Minimum: 1? 2?
- Maximum: 5? 10?

**Question 4: API Endpoint Design**
For the food search backend, create:
- New endpoint: `GET /foods/search?q=scrambled` returning JSON?
- Or leverage existing? (if any exist)
- Response format: `[{id: 123, description: "...", carbs: 13, protein: 11, fat: 11}, ...]`?

**Question 5: Selected Foods Display**
For the tag-style UI showing selected foods:
- Match category tag styling exactly (indigo bg, gray text)?
- Show food name only on tag?
- Show macros on tag as well, or just in results?
- Include remove button (X) like categories do?

### Technical Plan (Once Decisions Made)

1. **Backend Work:**
   - Create `FoodsController#search` endpoint
   - Query: `Food.where("description ILIKE ?", "%#{query}%")`
   - Include macro data via `NutrientLookupService`
   - Return JSON with food id, description, macros per 100g
   - Rate limiting: Only search if ≥2 characters typed

2. **Frontend Work:**
   - Create new Stimulus controller: `food_selector_controller.js`
   - Text input for search
   - Dropdown for autocomplete results
   - Selected foods displayed as tags (similar to `category_selector_controller.js`)
   - Remove button on each tag
   - Enforce min/max selection limits

3. **View Updates:**
   - Update `_meal_structure_item_fields.html.erb`
   - Replace "Coming Soon" div with actual food search UI
   - Add search input and results container
   - Add selected foods tag display

### Key Files to Modify When Ready

- `app/controllers/daily_meal_structures_controller.rb` - already updated ✅
- `app/models/meal_structure_item.rb` - already updated ✅
- `app/views/daily_meal_structures/_meal_structure_item_fields.html.erb` - replace Coming Soon section
- `app/javascript/controllers/food_selector_controller.js` - NEW controller to create
- Potentially create: `app/controllers/foods_controller.rb` with search action

### Context for Next Session

When resuming:
1. Answer the 5 design questions above
2. Reference this section in the docs for implementation details
3. Start with backend: FoodsController#search endpoint
4. Then build frontend: food_selector_controller.js
5. Update the view to use the new controller

The groundwork is complete - mode toggle works, validation is in place, parameters are cleaned up. Just needs the search UI on top.
