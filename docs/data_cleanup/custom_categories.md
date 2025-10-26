# Tier 3 Analysis: Custom Categories for Meal Composer

Based on analysis of the current preprocessed FNDDS data, here's what we're working with and the challenges/approach for Tier 3.

---

## Current State After Tiers 1 & 2

### Data Summary
- **73 clean FNDDS categories** (down from 173 original)
- **775 deduplicated foods** (down from 5,432 raw foods)
- Categories range from very granular (6407: "Broccoli") to broad (6420: "Other vegetables and combinations")

### Quality of Preprocessing
- ✅ Tier 1 (category exclusion): Successfully removed unsuitable categories
- ✅ Tier 2 (deduplication): Smart scoring system kept "NS as to cooking method" variants, which are actually GOOD for meal planning (generic)
- ✅ Most foods are now simple, single-ingredient items

---

## Key Challenges for Tier 3 Custom Categories

### 1. FNDDS Categories Are Inconsistent in Granularity

**Problem Examples:**
- **Too granular:** "6407: Broccoli" is its own category (5 foods), but "6411: Other dark green vegetables" lumps together spinach, kale, chard, arugula (dozens of foods)
- **Mixed purposes:** "2202: Chicken, whole pieces" contains breast, thigh, drumstick, wing, feet, AND skin - not intuitive groupings
- **Arbitrary splits:** "8012: Salad dressings and vegetable oils" mixes cooking fats (oils) with salad toppings (dressings) - users would want these separate

**Impact on Meal Composer:**
- User selects "Broccoli" → gets 5 variations, great!
- User selects "Other dark green vegetables" → might get spinach OR kale OR arugula - not controllable
- User wants "cooking oil" → has to wade through 30+ salad dressings

### 2. Protein Categories Don't Match User Mental Models

**Current FNDDS Structure:**
```
2002: "Beef, excludes ground" - steaks, roasts, corned beef, jerky, veal (81 foods!)
2004: "Ground beef" - ground beef, patties (3 foods)
2202: "Chicken, whole pieces" - breast, thigh, drumstick, wing, feet, skin (13 foods)
```

**What Users Actually Think About Meal Planning:**
- "I want chicken breast for this meal" (specific cut)
- "I want a beef steak" vs "I want ground beef" (different macro profiles)
- Users don't think "chicken whole pieces" - they think "white meat" vs "dark meat"

### 3. Vegetables Need Better Organization

**Current Issues:**
- Starchy vs non-starchy mixed in same categories
- "Other vegetables and combinations" is a catch-all (unclear what's in it)
- No distinction between high-carb vegetables (corn, peas) and low-carb (leafy greens)

**Why This Matters:**
- Macro targets: Leafy greens are mostly protein/fiber, potatoes are mostly carbs
- Meal structure: User might want "leafy greens for salad" separate from "roasted vegetables"

### 4. "NS as to" Foods Are Actually Good But Look Bad

**Observation:**
The deduplication script correctly kept foods like:
- "Chicken breast, NS as to cooking method, skin not eaten"
- "Broccoli, NS as to form, cooked"

These are PERFECT for meal planning because they're generic macro averages. But the names are ugly and confusing for users.

**Solution Needed:**
Custom categories should use clean display names:
- Display: "Chicken breast (boneless, skinless)"
- Underlying FNDDS food: "Chicken breast, NS as to cooking method, skin not eaten"

---

## Recommended Custom Category Structure

### High-Level Approach

**Option A: Flatten and Split** (RECOMMENDED)
- Create 20-30 flat, intuitive categories
- Split overly broad FNDDS categories (e.g., "Chicken, whole pieces" → "Chicken breast", "Chicken thighs", "Chicken wings")
- Merge overly narrow categories (e.g., combine berry categories)
- Add `meal_category` string field to `Food` model

**Option B: Hierarchical with Tags**
- Keep ~15 high-level categories (Proteins, Vegetables, Grains, etc.)
- Add tags for subcategories (e.g., "leafy-greens", "cruciferous", "starchy")
- More flexible but more complex UI

**Recommendation: Option A** - simpler, more aligned with how FlexibleMealComposer currently works (selects by category name)

---

## Proposed Custom Categories (32 categories)

### PROTEINS (11 categories)

| Custom Category | FNDDS Source Categories | Food Count (est) |
|----------------|------------------------|------------------|
| `Beef steaks` | 2002 (filtered for "steak") | ~6 |
| `Ground beef` | 2004 | ~3 |
| `Pork chops` | 2006 (filtered) | ~4 |
| `Chicken breast` | 2202 (filtered) | ~2 |
| `Chicken thighs` | 2202 (filtered) | ~2 |
| `Turkey` | 2206 | ~8 |
| `Lamb and game meats` | 2008 (lamb, venison, bison, rabbit, etc.) | ~17 |
| `Organ meats` | 2010 (liver, heart, kidney, etc.) | ~9 |
| `Fish` | 2402 | ~11 |
| `Shellfish` | 2404 | ~11 |
| `Eggs` | 2502 | ~2 |

### VEGETABLES (8 categories)

| Custom Category | FNDDS Source Categories | Food Count (est) |
|----------------|------------------------|------------------|
| `Leafy greens` | 6409, 6410, 6411 (spinach, kale, lettuce, arugula) | ~25 |
| `Cruciferous vegetables` | 6407, 6413 (broccoli, cauliflower, cabbage, brussels sprouts) | ~10 |
| `Root vegetables` | 6404, 6406 (carrots, beets, turnips) | ~15 |
| `Tomatoes` | 6402 | ~8 |
| `Peppers and onions` | 6414, 6420 (filtered) | ~15 |
| `Other vegetables` | 6412, 6418, 6420 (string beans, zucchini, mushrooms, etc.) | ~35 |
| `Starchy vegetables` | 6416, 6418, 6802, 6806 (corn, peas, potatoes, sweet potatoes) | ~15 |
| `Frozen vegetable mixes` | Remove or keep minimal | ~5 |

### FRUITS (4 categories)

| Custom Category | FNDDS Source Categories | Food Count (est) |
|----------------|------------------------|------------------|
| `Berries` | 6009, 6011 (strawberries, blueberries, raspberries) | ~10 |
| `Tropical fruits` | 6004, 6014, 6022, 6024 (bananas, melons, pineapple, mango) | ~15 |
| `Stone fruits and citrus` | 6008, 6012, 6020 (peaches, oranges, pears) | ~20 |
| `Apples and grapes` | 6002, 6006 | ~8 |

### GRAINS (3 categories)

| Custom Category | FNDDS Source Categories | Food Count (est) |
|----------------|------------------------|------------------|
| `Rice` | 4002 | ~4 |
| `Pasta and noodles` | 4004 | ~10 |
| `Bread` | 4202, 4204, 4206, 4208 | ~20 |

### FATS (2 categories)

| Custom Category | FNDDS Source Categories | Food Count (est) |
|----------------|------------------------|------------------|
| `Cooking oils` | 8012 (oils only, ~15 foods) | ~15 |
| `Butter and animal fats` | 8002 | ~3 |

### DAIRY (3 categories)

| Custom Category | FNDDS Source Categories | Food Count (est) |
|----------------|------------------------|------------------|
| `Milk` | 1002, 1004, 1006, 1008 (collapse fat variations?) | ~10 |
| `Cheese` | 1602, 1604 | ~25 |
| `Yogurt` | 1820, 1822 | ~10 |

### OTHER (1 category)

| Custom Category | FNDDS Source Categories | Food Count (est) |
|----------------|------------------------|------------------|
| `Nuts and seeds` | 2804 | ~16 |

---

## Implementation Complexities & Solutions

### Complexity 1: Many-to-Many Mapping

**Problem:** Some FNDDS categories need to be SPLIT across multiple custom categories.

**Example:**
- FNDDS 2202 "Chicken, whole pieces" contains:
  - Chicken breast → Custom category: `Chicken breast`
  - Chicken thigh → Custom category: `Chicken thighs`
  - Chicken wing → Custom category: `Other chicken parts` (?)
  - Chicken feet → Remove entirely

**Solution:**
Pattern-matching rules in mapping script:

```ruby
# Pseudo-code example
if food.category_code == "2202"
  case food.description
  when /breast/i
    food.meal_category = "Chicken breast"
  when /thigh/i
    food.meal_category = "Chicken thighs"
  when /wing/i
    food.meal_category = "Chicken wings"
  when /feet|skin/i
    food.meal_category = nil  # Exclude
  else
    food.meal_category = "Other chicken parts"
  end
end
```

### Complexity 2: Should We Remove More Foods?

**Current Issue:** Even after deduplication, we have:
- Multiple fat levels of milk (whole, 2%, skim)
- Multiple fat levels of cheese (regular, light, fat free)
- Multiple fat levels of salad dressings

**Questions:**
1. **Milk:** Keep all fat levels or just whole milk?
   - **Recommendation:** Keep whole, low-fat, and skim (3 total) - significant macro differences

2. **Cheese:** Keep all variations?
   - **Recommendation:** Remove "light" and "fat free" - users expect real cheese, macros are more reliable

3. **Salad dressings:** 48 dressings in category 8012!
   - **Recommendation:** Remove ALL salad dressings from meal planning - they're not meal components
   - Keep ONLY the 15 cooking oils (olive, coconut, avocado, etc.)

### Complexity 3: Display Names vs Database Names

**Problem:** "Chicken breast, NS as to cooking method, skin not eaten" is technically correct but ugly.

**Solution:** Add a `display_name` field to foods?

**Alternative (simpler):** Just live with the FNDDS names - they're fine once users understand "NS as to cooking method" means "generic cooked"

**Recommendation:** Defer display names to future enhancement - not critical for Tier 3

### Complexity 4: Testing Custom Categories

**Problem:** How do you verify the mapping worked correctly?

**Solution:** Generate analysis reports during mapping:

```ruby
# After mapping script runs:
# 1. Count foods per custom category
# 2. List any foods that didn't get mapped
# 3. Show sample foods from each category for manual review
```

---

## Recommended Implementation Approach

### Step 1: Create Mapping Rules (script/fndds/map_custom_categories.rb)

```ruby
# Input: food_deduplicated.csv
# Output: food_with_custom_categories.csv (adds meal_category column)

CATEGORY_MAPPING_RULES = {
  # Simple 1-to-1 mappings (FNDDS category → custom category)
  "4002" => "Rice",
  "2502" => "Eggs",
  "2402" => "Fish",
  "2404" => "Shellfish",

  # Complex mappings (pattern-based, see Complexity 1)
  "2202" => :split_chicken_parts,  # Custom function
  "8012" => :oils_only,  # Exclude dressings
  # ... etc
}

EXCLUDE_ENTIRELY = [
  # Patterns for foods to remove even after deduplication
  /feet/i,  # Chicken feet
  /skin/i,  # Chicken skin (if separate)
  # ... salad dressings (see below)
]
```

### Step 2: Handle Salad Dressings Special Case

**Decision needed:** Keep or remove salad dressings?

**Argument for removing:**
- Not whole foods
- Highly processed
- Macro-unreliable (fat-free versions use thickeners, etc.)
- Users won't "cook with" Ranch dressing

**Argument for keeping:**
- Category 8012 is already whitelisted in Tier 1
- Some users might want dressings for salads
- Easy to filter out later if unused

**Recommendation:** REMOVE all salad dressings, keep only oils:

```ruby
if food.category_code == "8012"
  if food.description.match?(/oil/i)
    food.meal_category = "Cooking oils"
  else
    # It's a salad dressing, exclude
    next
  end
end
```

### Step 3: Add MealCategory Model and Migration

**UPDATED RECOMMENDATION: Use Option B (Separate Model)**

After analyzing the codebase, Option B is better because:
1. You already use `FoodCategory` extensively in UI (checkboxes for meal structure)
2. You'll want display names, descriptions, and sort order for the UI
3. Type safety prevents bugs from typo'd category names
4. Cleaner data model with proper foreign keys

**Migration:**

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_meal_categories.rb
class CreateMealCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :meal_categories do |t|
      t.string :name, null: false           # Internal name: "chicken_breast"
      t.string :display_name, null: false   # UI name: "Chicken Breast"
      t.text :description                   # Optional: "Boneless, skinless chicken breast"
      t.integer :sort_order, default: 0     # For ordering in UI
      t.string :macro_profile                # Optional: "high-protein", "high-fat", "high-carb"

      t.timestamps
    end

    add_index :meal_categories, :name, unique: true
    add_index :meal_categories, :sort_order

    # Add foreign key to foods table
    add_reference :foods, :meal_category, foreign_key: true, index: true
  end
end
```

**Model:**

```ruby
# app/models/meal_category.rb
class MealCategory < ApplicationRecord
  has_many :foods, dependent: :nullify

  validates :name, presence: true, uniqueness: true
  validates :display_name, presence: true
  validates :sort_order, numericality: { only_integer: true }

  # Scope for ordering in UI
  scope :ordered, -> { order(:sort_order, :display_name) }

  # Helper to get foods with complete macro data
  def foods_with_complete_macros
    foods.includes(:food_nutrients)
         .where.not(food_nutrients: { amount: nil })
         .group('foods.id')
         .having('COUNT(food_nutrients.id) >= 3')  # At least carbs, protein, fat
  end
end
```

**Update Food Model:**

```ruby
# app/models/food.rb
class Food < ApplicationRecord
  belongs_to :food_category              # Keep for reference (FNDDS category)
  belongs_to :meal_category, optional: true  # New: custom meal planning category

  has_many :food_nutrients, foreign_key: :fdc_id, primary_key: :fdc_id, dependent: :destroy
  has_many :nutrients, through: :food_nutrients

  validates :fdc_id, presence: true, uniqueness: true
  validates :description, presence: true
  validates :food_category, presence: true
  validates :publication_date, presence: true

  # Scopes for meal planning
  scope :meal_plannable, -> { where.not(meal_category_id: nil) }
  scope :by_meal_category, ->(category_name) {
    joins(:meal_category).where(meal_categories: { name: category_name })
  }
end
```

### Step 4: Seed MealCategories

Create a new seed file to populate the 32 meal categories:

```ruby
# db/seeds/meal_categories.rb
puts "Seeding meal categories..."

meal_categories_data = [
  # PROTEINS (sort_order: 1-11)
  { name: "beef_steaks", display_name: "Beef Steaks", sort_order: 1, macro_profile: "high-protein" },
  { name: "ground_beef", display_name: "Ground Beef", sort_order: 2, macro_profile: "high-protein" },
  { name: "pork_chops", display_name: "Pork Chops", sort_order: 3, macro_profile: "high-protein" },
  { name: "chicken_breast", display_name: "Chicken Breast", sort_order: 4, macro_profile: "high-protein", description: "Boneless, skinless chicken breast" },
  { name: "chicken_thighs", display_name: "Chicken Thighs", sort_order: 5, macro_profile: "high-protein", description: "Boneless, skinless chicken thighs" },
  { name: "turkey", display_name: "Turkey", sort_order: 6, macro_profile: "high-protein" },
  { name: "lamb_and_game", display_name: "Lamb & Game Meats", sort_order: 7, macro_profile: "high-protein", description: "Lamb, venison, bison, rabbit, etc." },
  { name: "organ_meats", display_name: "Organ Meats", sort_order: 8, macro_profile: "high-protein", description: "Liver, heart, kidney" },
  { name: "fish", display_name: "Fish", sort_order: 9, macro_profile: "high-protein" },
  { name: "shellfish", display_name: "Shellfish", sort_order: 10, macro_profile: "high-protein" },
  { name: "eggs", display_name: "Eggs", sort_order: 11, macro_profile: "high-protein" },

  # VEGETABLES (sort_order: 12-19)
  { name: "leafy_greens", display_name: "Leafy Greens", sort_order: 12, description: "Spinach, kale, lettuce, arugula" },
  { name: "cruciferous", display_name: "Cruciferous Vegetables", sort_order: 13, description: "Broccoli, cauliflower, cabbage, brussels sprouts" },
  { name: "root_vegetables", display_name: "Root Vegetables", sort_order: 14, description: "Carrots, beets, turnips" },
  { name: "tomatoes", display_name: "Tomatoes", sort_order: 15 },
  { name: "peppers_onions", display_name: "Peppers & Onions", sort_order: 16 },
  { name: "other_vegetables", display_name: "Other Vegetables", sort_order: 17, description: "String beans, zucchini, mushrooms, etc." },
  { name: "starchy_vegetables", display_name: "Starchy Vegetables", sort_order: 18, macro_profile: "high-carb", description: "Potatoes, sweet potatoes, corn, peas" },

  # FRUITS (sort_order: 20-23)
  { name: "berries", display_name: "Berries", sort_order: 20, description: "Strawberries, blueberries, raspberries" },
  { name: "tropical_fruits", display_name: "Tropical Fruits", sort_order: 21, description: "Bananas, melons, pineapple, mango" },
  { name: "stone_citrus", display_name: "Stone Fruits & Citrus", sort_order: 22, description: "Peaches, oranges, pears" },
  { name: "apples_grapes", display_name: "Apples & Grapes", sort_order: 23 },

  # GRAINS (sort_order: 24-26)
  { name: "rice", display_name: "Rice", sort_order: 24, macro_profile: "high-carb" },
  { name: "pasta_noodles", display_name: "Pasta & Noodles", sort_order: 25, macro_profile: "high-carb" },
  { name: "bread", display_name: "Bread", sort_order: 26, macro_profile: "high-carb" },

  # FATS (sort_order: 27-28)
  { name: "cooking_oils", display_name: "Cooking Oils", sort_order: 27, macro_profile: "high-fat", description: "Olive oil, coconut oil, avocado oil, etc." },
  { name: "butter_fats", display_name: "Butter & Animal Fats", sort_order: 28, macro_profile: "high-fat" },

  # DAIRY (sort_order: 29-31)
  { name: "milk", display_name: "Milk", sort_order: 29 },
  { name: "cheese", display_name: "Cheese", sort_order: 30 },
  { name: "yogurt", display_name: "Yogurt", sort_order: 31 },

  # OTHER (sort_order: 32)
  { name: "nuts_seeds", display_name: "Nuts & Seeds", sort_order: 32, macro_profile: "high-fat" }
]

meal_categories_data.each do |data|
  MealCategory.find_or_create_by!(name: data[:name]) do |category|
    category.display_name = data[:display_name]
    category.description = data[:description]
    category.sort_order = data[:sort_order]
    category.macro_profile = data[:macro_profile]
  end
end

puts "✅ #{MealCategory.count} meal categories seeded."
```

### Step 5: Update Food Seeds to Assign MealCategories

```ruby
# db/seeds/fndds/foods.rb
# After loading foods, assign meal_category_id based on mapping rules

puts "Assigning meal categories to foods..."

# Pre-load meal category IDs
meal_category_ids = MealCategory.pluck(:name, :id).to_h

# Iterate through all foods and assign meal_category_id
Food.find_each do |food|
  fndds_category = food.food_category.code
  description = food.description

  meal_category_name = determine_meal_category(fndds_category, description)

  if meal_category_name && meal_category_ids[meal_category_name]
    food.update_column(:meal_category_id, meal_category_ids[meal_category_name])
  end
end

def determine_meal_category(fndds_code, description)
  # Implement mapping logic from script/fndds/map_custom_categories.rb
  # Return meal category name (e.g., "chicken_breast") or nil
end
```

### Step 6: Update FlexibleMealComposer Service

**Current code uses `FoodCategory`, needs to change to `MealCategory`:**

```ruby
# app/services/flexible_meal_composer.rb

# BEFORE (line 122-137):
def resolve_category_descriptions(structure)
  resolved = {}

  structure.each do |meal_type, category_descriptions|
    resolved[meal_type] = category_descriptions.map do |description|
      category = FoodCategory.find_by(description: description)

      unless category
        raise "Unknown food category: #{description}"
      end

      category.id
    end
  end

  resolved
end

# AFTER:
def resolve_category_names(structure)
  resolved = {}

  structure.each do |meal_type, category_names|
    resolved[meal_type] = category_names.map do |name|
      category = MealCategory.find_by(name: name)

      unless category
        raise "Unknown meal category: #{name}"
      end

      category.id
    end
  end

  resolved
end
```

**Update meal structure format:**

```ruby
# BEFORE (line 32-39):
DEFAULT_MEAL_STRUCTURE = {
  breakfast: [ "Dairy and Egg Products", "Cereal Grains and Pasta",
              "Fruits and Fruit Juices", "Fats and Oils" ],
  lunch: [ "Poultry Products", "Vegetables and Vegetable Products",
          "Legumes and Legume Products", "Cereal Grains and Pasta", "Fats and Oils" ],
  dinner: [ "Beef Products", "Vegetables and Vegetable Products",
           "Cereal Grains and Pasta", "Fats and Oils", "Nut and Seed Products" ]
}

# AFTER:
DEFAULT_MEAL_STRUCTURE = {
  breakfast: [ "eggs", "bread", "berries", "cooking_oils" ],
  lunch: [ "chicken_breast", "leafy_greens", "rice", "cooking_oils" ],
  dinner: [ "beef_steaks", "cruciferous", "starchy_vegetables", "cooking_oils" ]
}
```

**Update food selection to use meal_category_id:**

```ruby
# BEFORE (line 240):
random_foods = Food.where(food_category_id: category_id).order("RANDOM()").limit(5)

# AFTER:
random_foods = Food.where(meal_category_id: category_id).order("RANDOM()").limit(5)

# BEFORE (line 245):
selected_food = Food.where(food_category_id: category_id).order("RANDOM()").first

# AFTER:
selected_food = Food.where(meal_category_id: category_id).order("RANDOM()").first

# BEFORE (line 280):
category = FoodCategory.find_by(id: food.food_category_id)

# AFTER:
category = MealCategory.find_by(id: food.meal_category_id)
```

**Update compose_daily_meals method call:**

```ruby
# BEFORE (line 61):
category_structure = resolve_category_descriptions(meal_structure)

# AFTER:
category_structure = resolve_category_names(meal_structure)
```

### Step 7: Update MealStructureItem Model

**Keep both FoodCategory and MealCategory support:**

```ruby
# app/models/meal_structure_item.rb

# Add new validation for meal_category_ids
validate :meal_categories_exist

def meal_categories_exist
  return if meal_category_ids.blank?

  existing_ids = MealCategory.where(id: meal_category_ids).pluck(:id)
  invalid_ids = meal_category_ids - existing_ids

  if invalid_ids.any?
    errors.add(:meal_category_ids, "contains invalid category IDs: #{invalid_ids.join(', ')}")
  end
end

# Update migration to add meal_category_ids
# db/migrate/YYYYMMDDHHMMSS_add_meal_category_ids_to_meal_structure_items.rb
class AddMealCategoryIdsToMealStructureItems < ActiveRecord::Migration[8.0]
  def change
    add_column :meal_structure_items, :meal_category_ids, :integer, array: true, default: []
  end
end
```

### Step 8: Update Controllers

```ruby
# app/controllers/daily_meal_structures_controller.rb

# Update strong parameters to include meal_category_ids
def meal_structure_item_params
  params.require(:meal_structure_item).permit(
    :meal_label,
    :mode,
    food_category_ids: [],    # Keep for backward compatibility
    meal_category_ids: [],    # Add new
    food_ids: []
  )
end
```

### Step 9: Update Views

```ruby
# app/views/daily_meal_structures/_meal_structure_item_fields.html.erb

# BEFORE:
<%= render "meal_structure_item_fields", form: item_form, food_categories: FoodCategory.order(:description) %>

# AFTER (show MealCategory instead):
<%= render "meal_structure_item_fields", form: item_form, categories: MealCategory.ordered %>

# Update the checkbox loop:
# BEFORE:
<% food_categories.each do |category| %>
  <div class="flex items-center space-x-2">
    <%= check_box_tag "#{form.object_name}[food_category_ids][]",
                     category.id,
                     form.object.food_category_ids&.include?(category.id),
                     class: "rounded" %>
    <%= label_tag "#{form.object_name}_food_category_ids_#{category.id}",
                 category.description,
                 class: "text-sm" %>
  </div>
<% end %>

# AFTER:
<% categories.each do |category| %>
  <div class="flex items-center space-x-2">
    <%= check_box_tag "#{form.object_name}[meal_category_ids][]",
                     category.id,
                     form.object.meal_category_ids&.include?(category.id),
                     class: "rounded" %>
    <%= label_tag "#{form.object_name}_meal_category_ids_#{category.id}",
                 category.display_name,
                 class: "text-sm" %>
    <% if category.description.present? %>
      <span class="text-xs text-gray-500">(<%= category.description %>)</span>
    <% end %>
  </div>
<% end %>
```

### Step 10: Update MealPlanGenerator Service

```ruby
# app/services/meal_plan_generator.rb

# Find the line that uses food_category_ids and update to meal_category_ids
# BEFORE:
category_ids = meal_structure_item.food_category_ids

# AFTER:
category_ids = meal_structure_item.meal_category_ids || meal_structure_item.food_category_ids

# This allows backward compatibility during migration
```

### Step 11: Update ThreeIngredientComposer (if still used)

```ruby
# app/services/three_ingredient_composer.rb

# Update to use MealCategory instead of FoodCategory
# BEFORE:
FoodCategory.all.each do |category|

# AFTER:
MealCategory.all.each do |category|

# BEFORE:
category = FoodCategory.find_by(id: category_id)

# AFTER:
category = MealCategory.find_by(id: category_id)

# BEFORE:
foods_in_category = Food.where(food_category_id: category_id)

# AFTER:
foods_in_category = Food.where(meal_category_id: category_id)
```

### Step 12: Manual Review and Iteration

1. Run migrations: `bin/rails db:migrate`
2. Seed meal categories: `bin/rails db:seed` (or run meal_categories seed separately)
3. Run mapping script to assign meal_category_id to foods
4. Test in Rails console:
   ```ruby
   MealCategory.all.map { |cat| [cat.name, cat.foods.count] }
   Food.where(meal_category: MealCategory.find_by(name: "chicken_breast")).pluck(:description)
   ```
5. Test FlexibleMealComposer with new meal structure
6. Update UI to use MealCategory instead of FoodCategory
7. Identify any misclassified foods
8. Adjust mapping rules
9. Re-run preprocessing pipeline

---

## Open Questions to Resolve

Before implementing Tier 3, you need to decide:

1. **Milk fat levels:** Keep all 3-4 fat levels or just whole milk?
   - Recommendation: Keep whole, low-fat, skim (macro differences matter)

2. **Cheese varieties:** Keep all named cheeses (cheddar, mozzarella, swiss) or collapse to "Cheese"?
   - Recommendation: Keep varieties - users might have preferences, macros are similar enough

3. **Ground vs whole cuts:** For beef/pork, separate ground meat from whole cuts?
   - Recommendation: YES - "Ground beef" vs "Beef steaks" (different cooking methods, macro profiles)

4. **Cured meats:** Keep bacon, sausage, ham, or remove as "processed"?
   - Recommendation: Keep minimal (bacon, ham) - users do cook with these

5. **Organ meats:** Keep liver, organ meats (category 2010)?
   - **Updated Recommendation:** KEEP - legitimate whole foods protein source (liver, heart, kidney)
   - Some users specifically seek out organ meats for their nutritional density
   - Category 2010 has ~9 foods after deduplication

6. **Frozen vs fresh vegetables:** Deduplicate more aggressively?
   - Recommendation: Already handled well by Tier 2 - leave as-is

7. **Salad dressings:** Keep or remove entirely from category 8012?
   - Recommendation: REMOVE - not whole foods, keep only oils

8. **Bread subcategories:** Keep "Yeast breads" separate from "Rolls and buns"?
   - Recommendation: Merge into single "Bread" category - macro profiles similar

---

## Estimated Work

**Coding:**
- MealCategory model + migration: ~50 lines
- Meal categories seed file: ~50 lines
- Mapping script (FNDDS → MealCategory): ~200 lines with rules for all 73 categories
- FlexibleMealComposer updates: ~50 lines (multiple files)
- MealStructureItem updates: ~30 lines
- Controller updates: ~10 lines
- View updates: ~30 lines
- ThreeIngredientComposer updates: ~20 lines

**Total code changes:** ~440 lines across 10+ files

**Manual Work:**
- Defining all 32 custom categories and mapping rules: ~3-4 hours
- Running migrations and seeds: ~30 minutes
- Testing and iteration: ~2-3 hours
- Reviewing final food lists: ~1 hour
- Updating existing meal structures in database: ~30 minutes

**Total:** ~1.5-2 days of focused work

---

## Final Recommendation

**Proceed with Tier 3 using MealCategory model approach:**

1. Create 32 custom meal categories as separate model (not string field)
2. Keep FoodCategory for FNDDS reference, add MealCategory for meal planning
3. Remove salad dressings (keep only oils)
4. Keep organ meats (liver, heart, kidney) and game meats (lamb, venison, bison, etc.) - legitimate whole food proteins
5. Keep cheese/milk varieties (macro differences matter)
6. Split chicken, beef into specific cuts
7. Update all services, controllers, views to use MealCategory instead of FoodCategory
8. Generate analysis reports for manual review
9. Iterate on mapping rules until categories look correct

**Expected outcome:** ~650-700 foods across 32 intuitive categories, ready for meal planning.

---

## Summary of Code Changes

### Files to Create:
1. `db/migrate/YYYYMMDDHHMMSS_create_meal_categories.rb` - New table for custom categories
2. `db/migrate/YYYYMMDDHHMMSS_add_meal_category_ids_to_meal_structure_items.rb` - Add support to meal structure
3. `app/models/meal_category.rb` - New model
4. `db/seeds/meal_categories.rb` - Seed 32 custom categories
5. `script/fndds/map_custom_categories.rb` - Mapping logic (reuse from preprocessing)

### Files to Modify:
1. `app/models/food.rb` - Add `belongs_to :meal_category, optional: true`
2. `app/models/meal_structure_item.rb` - Add `meal_category_ids` support + validation
3. `app/services/flexible_meal_composer.rb` - Replace `FoodCategory` with `MealCategory` (4 locations)
4. `app/services/three_ingredient_composer.rb` - Replace `FoodCategory` with `MealCategory` (3 locations)
5. `app/services/meal_plan_generator.rb` - Use `meal_category_ids` instead of `food_category_ids`
6. `app/controllers/daily_meal_structures_controller.rb` - Update strong params to include `meal_category_ids`
7. `app/views/daily_meal_structures/_form.html.erb` - Pass `MealCategory` instead of `FoodCategory`
8. `app/views/daily_meal_structures/_meal_structure_item_fields.html.erb` - Display MealCategory checkboxes with display names
9. `db/seeds/fndds/foods.rb` - Assign `meal_category_id` after loading foods

### Key Architectural Changes:

**Before:**
```ruby
Food → belongs_to :food_category (FNDDS category)
FlexibleMealComposer uses FoodCategory.find_by(description: "Poultry Products")
UI shows: "Poultry Products", "Beef Products", etc.
```

**After:**
```ruby
Food → belongs_to :food_category (FNDDS - kept for reference)
Food → belongs_to :meal_category (custom meal planning categories)
FlexibleMealComposer uses MealCategory.find_by(name: "chicken_breast")
UI shows: "Chicken Breast", "Beef Steaks", "Leafy Greens", etc.
```

### Migration Path:
1. **Phase 1:** Add MealCategory model and seed data (non-breaking)
2. **Phase 2:** Add meal_category_id to foods (non-breaking, nullable)
3. **Phase 3:** Update services to use MealCategory alongside FoodCategory (backward compatible)
4. **Phase 4:** Update UI to show MealCategory instead of FoodCategory
5. **Phase 5:** Deprecate FoodCategory usage in application code (keep model for reference)

### Backward Compatibility:
- Keep `food_category_id` on Food model (for FNDDS reference/auditing)
- Keep `food_category_ids` on MealStructureItem (for old meal structures)
- Services can check both `meal_category_ids` and `food_category_ids` during transition
- Gradual migration: old meal structures continue working, new ones use MealCategory
