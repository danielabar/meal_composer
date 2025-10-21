# Algorithm Optimization Analysis: Why Plans Sometimes Miss Macro Targets

## Overview

This document explains why the meal composition algorithm sometimes accepts and saves meal plans that don't fully meet the specified macro targets, even though they remain editable and regeneratable.

## The Core Problem

**Example from Plan #13 ("Strict Keto + Leftovers From Mother-in-law"):**

| Macro   | Target | Actual  | Difference | Within 8g Tolerance? |
| ------- | ------ | ------- | ---------- | -------------------- |
| Carbs   | 20g    | 21.62g  | +1.62g     | ✓ Yes                |
| Protein | 60g    | 41.05g  | **-19.0g** | ✗ **No**             |
| Fat     | 180g   | 172.83g | -7.17g     | ✓ Yes                |

- **Status:** `within_tolerance: false` (saved to DB anyway)
- **Reason:** Protein is 19g off, exceeding the 8g tolerance threshold

## Root Causes

### 1. The System is Actually Feasible (Not a Hard Constraint Problem)

Your meal structure uses **fixed food selections**, but this does NOT make the problem infeasible. In fact, the system is quite feasible:

**Mathematical feasibility test:**
- 11 foods = 11 unknown portion sizes
- 3 constraint equations (carbs, protein, fat)
- System is **massively underdetermined** (8 degrees of freedom)
- Maximum protein with all foods at 500g: **297.2g** ≫ 60g target
- Minimum protein with all foods at 10g: **5.94g** ≤ 60g target

**Therefore:** A solution that hits all three targets simultaneously should exist somewhere in the feasible region.

**The real problem:** Finding that solution is algorithmically difficult, not mathematically impossible.

### 3. Gradient Descent Gets Trapped (The Real Culprit)

With 11 variables optimizing toward 3 simultaneous targets, the gradient descent optimizer faces several challenges:

**Non-convex error surface:**
- The error landscape has multiple local minima
- The gradient may point toward one solution that violates other constraints
- Escaping local minima requires special techniques (simulated annealing, restarts, etc.)

**Competing objectives:**
- Lowering carb error might increase protein error
- Lowering protein error might increase fat error
- The optimizer oscillates instead of converging

**Current algorithm limitations:**
- **MAX_ITERATIONS = 200** may be insufficient for 11-dimensional search
- **LEARNING_RATE = 0.5** may cause oscillation (overshooting) or slow convergence
- **Linear gradient descent** doesn't handle constraints well—it hits the 10-500g boundaries and can't escape
- **No adaptive step-sizing** (like Adam optimizer)—just a fixed learning rate

**Example from your plan:**
The gradient descent might find:
- A point with 58g protein, 19g carbs, 182g fat (close but not quite)
- Adjusts portions slightly, now at 56g protein, 22g carbs, 178g fat (worse on carbs!)
- Keeps oscillating without converging to the feasible region

### 4. Tolerance Relaxation Strategy (Design Decision)

The algorithm uses **progressive tolerance relaxation** to avoid complete failure:

**From `MealPlanGenerator#optimize_portions` (lines 350-357):**

```ruby
tolerance = if last_resort
  MACRO_TOLERANCE_GRAMS * 4  # Very relaxed = 32g
elsif relaxed
  MACRO_TOLERANCE_GRAMS * 2  # Moderately relaxed = 16g
else
  MACRO_TOLERANCE_GRAMS      # Standard = 8g
end
```

**From `compose_meal_by_foods` (lines 207-256):**

```ruby
# Attempt 1-5: Standard 8g tolerance
# Attempt 6-10: Relaxed 16g tolerance
# Final attempt: 32g tolerance (last_resort: true)

# Your plan succeeded with last_resort: true
# Protein is 19g off, which is within 32g "good enough" threshold
```

**The Flow:**
1. Try to compose meal with standard 8g tolerance → **FAIL**
2. After 5 failed attempts, try with 16g tolerance → **FAIL**
3. One final attempt with 32g tolerance → **SUCCESS** (accept it!)
4. Save plan to database with `within_tolerance: false`

## Why The Algorithm Doesn't Fail Completely

**From `MealPlanGenerator#persist_meal_plan` (lines 425-441):**

```ruby
within_tolerance = (actual_carbs - daily_macro_target.carbs_grams).abs <= MACRO_TOLERANCE_GRAMS &&
                  (actual_protein - daily_macro_target.protein_grams).abs <= MACRO_TOLERANCE_GRAMS &&
                  (actual_fat - daily_macro_target.fat_grams).abs <= MACRO_TOLERANCE_GRAMS

daily_meal_plan = user.daily_meal_plans.create!(
  # ...
  within_tolerance: within_tolerance  # FALSE in your case
)
```

**Design Decision:** The system **prefers to save a suboptimal plan rather than fail completely**. Users can:
- See the deviation on the UI
- Regenerate the plan with different food selections
- Manually adjust the meal structure

This is a reasonable trade-off for user experience, but it masks underlying mathematical infeasibility.

## Why Your Specific Plan Has Protein Issues

### Not a Feasibility Problem, But an Optimization Problem

Your food selections **can theoretically hit 60g protein**:
- Salmon has 25.82g protein per 100g—could provide 40g+ with just 155g
- Chicken has 24.61g protein per 100g—could provide 20g+ with 80g
- Even coffee and cream add small amounts

**The challenge:** Finding portion sizes that simultaneously hit:
- **Carbs:** 20g (need vegetables + creams, not too many)
- **Protein:** 60g (need salmon + chicken, quite a bit)
- **Fat:** 180g (need olive oil at significant amounts)

**Why it failed:** The gradient descent optimizer couldn't find the right balance among these three competing targets. It converged to:
- Carbs: 21.62g ✓ (close)
- Protein: 41.05g ✗ (way off)
- Fat: 172.83g ✓ (close)

The optimizer likely prioritized carbs and fat, sacrificing protein in the process.

## Algorithm Constraints

### Current Limitations

1. **Per-meal distribution is rigid:**
   - Fixed: Breakfast 25% protein, Lunch 35%, Dinner 40%
   - For 60g total: 15g breakfast, 21g lunch, 24g dinner
   - Your foods can't hit these targets

2. **Portion size constraints are generous but limiting:**
   - MIN_PORTION_SIZE = 10g (too small to be practical)
   - MAX_PORTION_SIZE = 500g (too large for most foods)
   - Can't make salmon 150g (portion size unrealistic) or 500g (too much)

3. **No intelligent food selection:**
   - When protein is under-target, the algorithm doesn't proactively swap in higher-protein foods
   - It blindly tries to optimize whatever foods are selected

4. **Gradient descent gets stuck:**
   - MAX_ITERATIONS = 200 may not be enough for complex food combinations
   - LEARNING_RATE = 0.5 may cause oscillation instead of convergence

## Opportunities for Improvement

Your TODO file (lines 36-50 in `meal_plan_gen_todo.md`) already lists promising directions:

### 1. Weighted Error Function (Prioritize Problem Macros)

```ruby
# Example: heavily weight protein for aggressive targets
protein_weight = target_protein > 150 ? 2.0 : 1.0
total_error = carb_error**2 + (protein_error * protein_weight)**2 + fat_error**2
```

**Benefit:** When protein is critical, the optimizer focuses on that first rather than evenly balancing all three.

### 2. Macro-Specific Food Selection

```ruby
# Before optimization, if protein is under-target, bias selection
if target_protein > 120
  # Prefer: chicken, fish, turkey, eggs over vegetables
  # For lunch: pick salmon, then add complementary foods
else
  # Normal random selection
end
```

**Benefit:** Ensures the food combo has a chance of success before optimization even starts.

### 3. Two-Phase Optimization

```ruby
# Phase 1: Solve for protein + carbs (ignore fat initially)
optimize_for(protein, carbs)

# Phase 2: Fine-tune fat using oils/dressings
optimize_for(fat)
```

**Benefit:** Separates the constraint hierarchy. Protein is often the bottleneck, so solve that first.

### 4. Pre-Validation for Food-Based Mode

```ruby
# Before attempting optimization, check if solution is theoretically possible
max_protein = foods.sum { |f| f.protein_per_100g * MAX_PORTION_SIZE / 100 }
max_carbs = foods.sum { |f| f.carbs_per_100g * MAX_PORTION_SIZE / 100 }
max_fat = foods.sum { |f| f.fat_per_100g * MAX_PORTION_SIZE / 100 }

if target_protein > max_protein
  # Cannot succeed; suggest substitutions
  suggest_food_swap(:lunch, :salmon, :higher_protein_foods)
  return nil
end
```

**Benefit:** Fail fast with actionable feedback instead of silently accepting failure.

### 5. Better Tolerance Management

Instead of progressive relaxation:

```ruby
# Option A: Show trade-off to user
if can_meet_protein?
  optimize(standard_tolerance)
elsif can_meet_2_of_3_macros?
  optimize(relaxed_tolerance)
  notify_user("Best match: 41g protein, 2g carbs off, 7g fat off")
else
  return nil  # Genuinely impossible
end

# Option B: Auto-suggest food swaps
if solution.protein < target - 8
  suggest_swap(:lunch, :vegetable, :higher_protein_alternative)
end
```

**Benefit:** Transparency about constraints. Users understand why targets aren't met.

## Recommended Next Steps

### Short Term (Quick Wins)

1. **Add pre-validation** for food-based mode (detect impossible combinations)
2. **Implement weighted error** (prioritize protein when high target)
3. **Show theoretical limits** on UI ("These foods can deliver max 41g protein")

### Medium Term (Algorithmic Improvements)

1. **Two-phase optimization** (solve protein first, then carbs, then fat)
2. **Macro-specific food selection** (bias toward high-protein when needed)
3. **Better learning rate** or optimizer (consider simulated annealing)

### Long Term (UX/Feature Improvements)

1. **Allow user-specified tolerance** (let them accept ±15g if they want)
2. **Food swap suggestions** ("Replace broccoli with Greek yogurt to gain 15g protein")
3. **Macro distribution customization** (user specifies breakfast 15%, lunch 35%, dinner 50%, etc.)
4. **Caloric display** (complement macro targets with total calories)

## The Real Root Cause

Looking at `MealPlanGenerator#optimize_portions` (lines 359-391), the issue becomes clear:

```ruby
# Calculate current macros from portions
current_carbs = portions.each_with_index.sum { |p, i| p * coefficients[i][:carbs] }
current_protein = portions.each_with_index.sum { |p, i| p * coefficients[i][:protein] }
current_fat = portions.each_with_index.sum { |p, i| p * coefficients[i][:fat] }

# Calculate errors
carb_error = target_carbs - current_carbs
protein_error = target_protein - current_protein
fat_error = target_fat - current_fat

# Simple squared error—all macros weighted equally
total_error = carb_error**2 + protein_error**2 + fat_error**2

# Update portions with a fixed learning rate
gradient = 2 * (
  carb_error * coefficients[i][:carbs] +
  protein_error * coefficients[i][:protein] +
  fat_error * coefficients[i][:fat]
)

portions[i] += LEARNING_RATE * gradient
```

**The Problem:** This is a **naive steepest descent** approach with equal weighting for all three macros. When:
1. Increasing salmon portion raises protein (good) but also fat (bad)
2. Decreasing olive oil lowers fat (good) but can't improve protein much
3. The gradient oscillates between conflicting objectives

**Why it converged to "carbs ✓, fat ✓, protein ✗":**
- Carbs and fat have good "efficiency" with the selected foods
- Protein requires very specific portion ratios that the gradient descent couldn't find
- After 200 iterations with LEARNING_RATE = 0.5, it got stuck in a local minimum
- Then tolerance relaxation saved the suboptimal solution

## Key Takeaway

**The algorithm has a real optimization problem, not a feasibility problem.** Your food selections CAN hit all three targets, but the gradient descent optimizer:

1. Uses naive equal-weighted squared error (all macros equally important)
2. Has a fixed learning rate that may overshoot/undershoot
3. Gets trapped in local minima with 11 variables and conflicting objectives
4. Runs out of iterations (200) before finding a good solution
5. Falls back to "good enough" with tolerance relaxation

**This is fixable** through better optimization algorithms:
- **Weighted error function** (prioritize protein when needed)
- **Constrained optimization** (use Lagrange multipliers or penalty methods)
- **Better optimizer** (momentum, adaptive learning rate, or even linear programming)
- **Multi-start approach** (restart from different initial points)

The current behavior is a **design trade-off**—give users something rather than fail completely. But the underlying problem isn't that targets are impossible; it's that the optimizer isn't sophisticated enough to find the solution.
