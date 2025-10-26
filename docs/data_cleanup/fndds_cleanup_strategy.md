# FNDDS Data Cleanup Strategy

## Problem Analysis

### Current State
- **3,762 foods** after initial cleanup (removed baby foods, restaurant items, "with" composite foods, imitation foods)
- Still contains many unsuitable foods for the meal composer app
- FNDDS has **173 categories** but many are too specific or contain mixed/processed foods

### Key Issues with FNDDS Data

#### 1. Overly Specific Variations
Foods have excessive detail that doesn't matter for meal planning:
```
"Chicken, NS as to part, baked, broiled, or roasted, skin not eaten"
"Chicken, NS as to part, baked, broiled, or roasted, skin eaten"
"Chicken, NS as to part, rotisserie, NS as to skin eaten"
```
We only need: **"Chicken breast"** or **"Chicken thigh"**

#### 2. Incomplete Composite Food Filtering
Current filter catches "with" but misses other composite patterns:
```
"Beef and vegetables including carrots, broccoli, and/or dark-green leafy; no sauce"
"Chicken or turkey, noodles, and vegetables including carrots..."
"Pork, potatoes, and vegetables excluding carrots..."
```

#### 3. Preparation-Specific Entries
Multiple entries for same food in different states:
```
"Broccoli, raw"
"Broccoli, fresh, cooked, no added fat"
"Broccoli, frozen, cooked, no added fat"
"Broccoli, fresh, cooked, fat added, NS as to fat type"
"Fried broccoli"
```
We only need: **"Broccoli"** (user will cook it themselves)

#### 4. Ambiguous Food Names
- **"NS"** = Not Specified (e.g., "Chicken, NS as to part and cooking method")
- **"NFS"** = Not Further Specified
- These are too vague for precise macro calculations

#### 5. Unsuitable Categories
Many entire categories don't fit the whole-foods meal planning model:
- **Mixed dishes** (3002-3808): "Meat mixed dishes", "Pasta mixed dishes", "Burritos and tacos"
- **Processed items** (3702-3744): "Burgers", "Frankfurter sandwiches", "Pizza"
- **Baby foods** (9000 series): Still present despite initial cleanup
- **Sweets** (5500-5800): "Cakes and pies", "Candy", "Ice cream"
- **Most beverages** (7000 series): Only water/plain milk are relevant
- **Condiments** (8400 series): Some useful (oils) but many not (ketchup, dips)

### Why Foundation Foods Didn't Work
- **Too broad categories**: "Dairy and Egg Products" mixed milk, eggs, cheese, butter
  - User selects category → might get milk, eggs, OR egg powder
  - Can't ensure meal has specific protein (eggs) vs just dairy
- **Missing common foods**: No bread, only flours (oat flour, spelt flour)
- Would require similar cleanup effort

---

## Recommended Three-Tier Strategy

### Tier 1: Category-Level Exclusion
Remove entire unsuitable categories from the FNDDS dataset.

#### Categories to EXCLUDE:
```
3002-3808  Mixed dishes (meat, poultry, seafood, pasta, Asian, Mexican, soups)
3702-3744  Sandwiches and burgers
5002-5404  Breakfast bars, granola bars, cereal bars, nutrition bars
5502-5806  Sweets (cakes, pies, cookies, candy, ice cream, pudding)
7102-7506  Beverages except plain milk/water (juices, soft drinks, coffee, tea, alcohol)
7802-7804  Flavored/enhanced water
8402-8412  Most condiments (keep only: 8002 butter/fats, 8012 oils)
8802-8806  Sugars, sweeteners, syrups
9002-9602  All baby foods and formula
```

#### Categories to KEEP:
```
1002-1208  Plain milk (whole, reduced fat, lowfat, nonfat)
1602-1604  Cheese
1820-1822  Yogurt (regular, Greek)
1902-1904  Plant-based milk/yogurt
2002-2010  Beef, pork, lamb, organ meats
2202-2206  Chicken, turkey, poultry
2402-2404  Fish and shellfish
2502       Eggs
2602-2608  Cured meats (bacon, sausage - user might want these)
2802-2806  Beans, legumes, nuts, seeds, soy products
4002-4204  Grains, rice, pasta, bread, oats, quinoa
6002-6420  Fruits and vegetables (all subcategories)
6802-6806  Potatoes
8002       Butter and animal fats
8012       Salad dressings and vegetable oils
```

**Result**: Reduces from 173 categories to ~60-70 categories

---

### Tier 2: Food-Level Deduplication
Within kept categories, collapse redundant variations to simplest usable form.

#### Deduplication Rules:

**Rule 1: Remove preparation method variations**
```
KEEP:   "Chicken breast"
REMOVE: "Chicken breast, baked, broiled, or roasted, skin not eaten"
REMOVE: "Chicken breast, rotisserie, skin eaten"
REMOVE: "Chicken breast, fried, coated, skin / coating eaten"
```

**Rule 2: Collapse cooked/raw vegetable variations**
```
KEEP:   "Broccoli" (or "Broccoli, cooked")
REMOVE: "Broccoli, raw"
REMOVE: "Broccoli, fresh, cooked, no added fat"
REMOVE: "Broccoli, frozen, cooked, no added fat"
REMOVE: "Broccoli, fresh, cooked, fat added"
REMOVE: "Fried broccoli"
```

**Rule 3: Remove "NS" (Not Specified) entries**
```
REMOVE: "Chicken, NS as to part and cooking method"
REMOVE: "Milk, NS as to type"
```

**Rule 4: Remove "NFS" (Not Further Specified) entries**
```
REMOVE: "Cheese, NFS"
```

**Rule 5: Remove fried/breaded/coated versions**
```
KEEP:   "Fish"
REMOVE: "Fish, fried, coated"
REMOVE: "Fish, breaded, baked"
```

**Rule 6: Remove foods with sauces in the name**
```
REMOVE: "Chicken, grilled with sauce"
REMOVE: "Vegetables with cheese sauce"
```

**Rule 7: Keep simplest cheese/dairy entries**
```
KEEP:   "Cheddar cheese"
KEEP:   "Mozzarella cheese"
REMOVE: "Cheddar cheese, reduced fat"
REMOVE: "Cheddar cheese, low sodium"
REMOVE: "Cheese spread"
REMOVE: "Cheese dip"
```

**Rule 8: Remove combination vegetables**
```
KEEP:   "Broccoli"
KEEP:   "Cauliflower"
REMOVE: "Broccoli and cauliflower"
REMOVE: "Broccoli, cauliflower and carrots"
REMOVE: "Broccoli, cooked, as ingredient"
```

#### Implementation Pattern:
```ruby
EXCLUDE_FOOD_PATTERNS = [
  /, NS as to/i,                    # Not specified variations
  /, NFS$/i,                        # Not further specified
  /\b(fried|breaded|coated|battered)\b/i,
  /\b(with sauce|in sauce)\b/i,
  /, raw$/i,                        # Keep cooked version only
  /, frozen,/i,                     # Prefer fresh/generic
  /fat added/i,
  /\band\b/i,                       # Combination foods like "broccoli and cauliflower"
  /reduced fat|low fat|nonfat/i,    # Keep whole versions only (or vice versa - decide per category)
  /low sodium|no salt/i,
  /skin eaten|skin not eaten/i,
  /coating eaten|coating not eaten/i,
  /as ingredient$/i                 # "Broccoli, cooked, as ingredient"
]
```

**Result**: Reduces from ~3,000 foods to ~400-600 foods

---

### Tier 3: Custom Category Mapping
Create app-specific categories that make sense for meal composition.

#### Problem with FNDDS Categories:
- Too fine-grained: "Blueberries and other berries" vs "Strawberries" as separate categories
- Mixed purposes: Category 2202 "Chicken, whole pieces" mixes breasts, thighs, wings
- Doesn't match user mental model for meal planning

#### Proposed Custom Categories:

**PROTEINS:**
- Beef (steaks, roasts - not ground)
- Ground beef
- Pork
- Chicken breast
- Chicken thighs
- Turkey
- Fish
- Shellfish
- Eggs

**VEGETABLES:**
- Leafy greens (spinach, kale, lettuce)
- Cruciferous (broccoli, cauliflower, brussels sprouts)
- Root vegetables (carrots, beets, turnips)
- Starchy vegetables (potatoes, sweet potatoes, corn)
- Other vegetables (peppers, tomatoes, zucchini, mushrooms)

**FRUITS:**
- Berries (strawberries, blueberries, raspberries)
- Citrus (oranges, grapefruit, lemons)
- Stone fruits (peaches, plums, cherries)
- Tropical (bananas, pineapple, mango)
- Other fruits (apples, pears, grapes)

**GRAINS & STARCHES:**
- Rice (white, brown)
- Pasta
- Bread
- Oats
- Quinoa
- Other grains

**FATS:**
- Cooking oils (olive oil, vegetable oil, coconut oil)
- Butter
- Nuts (almonds, walnuts, peanuts)
- Seeds (chia, flax, sunflower)
- Avocado
- Salad dressings

**DAIRY:**
- Milk
- Cheese (cheddar, mozzarella, parmesan, etc.)
- Yogurt (plain, Greek)
- Cottage cheese

**LEGUMES:**
- Beans (black, kidney, pinto, chickpeas)
- Lentils
- Split peas

#### Implementation Approach:

**Option A: Map to custom categories in database**
- Keep `FoodCategory` model but populate with custom categories
- Add a `fndds_category_codes` field to track source
- Create mapping in seed script

**Option B: Add custom category field to foods**
- Add `meal_category` string to `Food` model
- Keep `food_category_id` pointing to FNDDS category for reference
- Seed script assigns `meal_category` based on rules

**Recommendation**: Option B is more flexible - allows future adjustments without restructuring categories

---

## Implementation Plan

### Phase 1: Analysis Scripts
Create scripts to analyze current data and validate approach:
1. `script/analyze_fndds_categories.rb` - Count foods per category, identify problems
2. `script/analyze_fndds_patterns.rb` - Find common patterns in food names

### Phase 2: Category Exclusion
Update `script/fndds/extract_clean_foods.rb`:
1. Add category-level exclusion list (codes 3002-3808, 5002+, etc.)
2. Filter by category code before pattern matching
3. Generate `food_clean.csv` with only suitable categories

### Phase 3: Food Deduplication
Create new `script/fndds/deduplicate_foods.rb`:
1. Load `food_clean.csv`
2. Apply pattern-based exclusions
3. For remaining duplicates, implement smart selection (prefer simplest name)
4. Generate `food_deduplicated.csv`

### Phase 4: Custom Category Mapping
Create `script/fndds/map_custom_categories.rb`:
1. Define custom category rules (pattern matching + manual overrides)
2. Add `meal_category` column to CSV
3. Generate `food_final.csv`

### Phase 5: Update Seed Process
Modify `db/seeds/fndds/`:
1. Update `foods.rb` to load `food_final.csv`
2. Create custom categories table (or add `meal_category` field)
3. Test seeding process
4. Update app to use custom categories

### Phase 6: Manual Review & Refinement
1. Seed database with cleaned data
2. Review foods in Rails console
3. Identify any remaining issues
4. Adjust rules and re-run

---

## Expected Outcomes

**Current State:**
- 173 FNDDS categories
- 3,762 foods (after initial cleanup)
- Many unusable for whole-foods meal planning

**Target State:**
- 15-25 custom meal categories
- 200-500 whole foods
- Each food is: single ingredient, unprocessed, cookable, macro-trackable

**Example Final Food List (per category):**
```
Chicken breast:
  - Chicken breast (boneless, skinless)
  - Chicken thigh (boneless, skinless)

Leafy greens:
  - Spinach
  - Kale
  - Swiss chard
  - Collard greens

Root vegetables:
  - Carrots
  - Beets
  - Turnips
  - Parsnips

Rice:
  - White rice
  - Brown rice
  - Basmati rice
  - Wild rice

Cooking oils:
  - Olive oil
  - Vegetable oil
  - Coconut oil
  - Avocado oil
```

---

## Alternative: Consider SR Legacy Dataset

If FNDDS cleanup proves too complex, **SR Legacy** might be worth reconsidering:
- More basic/generic foods (less specific variations)
- Simpler category structure
- "Standard Reference" foods are laboratory-analyzed (not survey-based)
- Might have better coverage of basic whole foods

**Action**: Before implementing full FNDDS cleanup, do a quick analysis of SR Legacy to compare suitability.

---

## Next Steps

1. **Review this strategy** - Does the three-tier approach make sense?
2. **Decide on custom categories** - Are the proposed categories right for your app?
3. **Choose implementation order** - Category exclusion first? Or explore SR Legacy?
4. **Implement Phase 1** - Run analysis scripts to validate assumptions

---

## Questions to Resolve

1. Should we keep multiple milk fat levels (whole, 2%, skim) or just one?
2. For vegetables, keep "cooked" version or let user choose raw vs cooked?
3. Do we need cured meats (bacon, sausage) or only whole cuts?
4. Should cheese varieties be separate foods or collapsed to "cheese"?
5. Ground beef vs whole cuts - both needed?

Let me know which direction you'd like to go and I can start implementing!
