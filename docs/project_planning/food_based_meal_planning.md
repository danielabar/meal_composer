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

### Option A (Minimal - Recommended for MVP):
- Keep `DailyMealStructure` as-is, but rename it conceptually or create a variant
- Change `MealStructureItem` to store either:
  - `food_category_ids` (existing, for category-based) OR
  - `food_ids` (new, for food-based)
  - Add a `mode: enum` field to distinguish: `mode: [:categories, :foods]`

### Option B (Cleaner long-term):
- Create a new `FoodBasedMealStructure` model mirroring `DailyMealStructure`
- Create a new `FoodBasedMealStructureItem` model with `food_ids` instead of `food_category_ids`
- Run both workflows side-by-side

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

## Recommended MVP Approach

### Phase 1: Prove algorithmic feasibility (this week)
- [ ] Create `MealPlanGeneratorByFood` service
- [ ] Test it in Rails console with hardcoded foods
- [ ] Verify it produces valid meal plans
- [ ] Document any edge cases or constraints

### Phase 2: Data modeling (next week)
- [ ] Add `mode` enum to `MealStructureItem` (or create new models)
- [ ] Add `food_ids` field alongside `food_category_ids`
- [ ] Update controllers/validations

### Phase 3: Basic UI (following week)
- [ ] Implement typeahead search for foods
- [ ] Show macro info inline
- [ ] Simple add/remove interface

### Phase 4: Full features (later)
- [ ] Favorites/history
- [ ] Macro filtering
- [ ] Suggestions

## Feasibility Verdict

| Aspect | Verdict | Effort |
|--------|---------|--------|
| Algorithm (optimizer) | ✅ **Trivial** | 2-4 hours |
| Data model | ✅ **Easy** | 2-3 hours |
| Service layer | ✅ **Straightforward** | 4-6 hours |
| Search UI | ⚠️ **Moderate** | 8-12 hours |
| Full feature parity | ⚠️ **Medium** | 20+ hours |

## Conclusion

**My recommendation:** Start with Phase 1 (algorithmic proof). Test in console. If it works, the path forward is clear and you'll have concrete data to justify the UI work. The algorithm is the unknown, but I'm quite confident it'll work—the gradient descent doesn't care where foods come from.
