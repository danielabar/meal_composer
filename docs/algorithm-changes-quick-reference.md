# Algorithm Changes - Quick Reference

## What Changed

Three focused improvements to `MealPlanGenerator#optimize_portions`:

### 1. Early Stopping (Convergence Detection)
```ruby
no_improvement_count += 1
break if no_improvement_count >= CONVERGENCE_PATIENCE  # 30
```
**Effect:** Exits immediately when stuck, saves ~30-100ms per meal

### 2. Random Restarts
```ruby
NUM_RESTARTS.times do |restart_num|
  portions = restart_num == 0 ? equal_portions : random_portions
  # run optimization, keep best
end
```
**Effect:** 2 attempts instead of 1 gives 2x chance to escape local minima

### 3. Conservative Learning Rate
```ruby
LEARNING_RATE = 0.3  # was 0.5
```
**Effect:** Smaller steps = less oscillation, more stable convergence

## What Did NOT Work (Removed)

- ❌ **Decay learning rate** (0.5 → 0.01) - Made convergence too slow
- ❌ **Weighted error** (2x protein) - Lost carb/fat precision
- ❌ **3 restarts** - Too slow (104 seconds for one plan!)
- ❌ **500 iterations** - Overkill when early stopping works

## Current Speed vs Before

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| Iterations per meal | 200 | 300 (but usually exits early) | +50% potential |
| Restarts | 1 | 2 | +100% |
| Typical time | ~5-10s total | ~5-15s total | Roughly same (early stopping helps) |
| Worst case | ~50s | ~30s | Better! |

## When to Use This Version

**Good for:**
- Picky eaters with specific food selections (food mode)
- High protein targets (60g+)
- Restrictive food combinations

**Still struggling with:**
- Mathematically infeasible combinations (can't fix those)
- Plans with extreme constraints

## Rolling Back If Needed

If performance is still a problem, revert constants to:
```ruby
MACRO_TOLERANCE_GRAMS = 8.0
MIN_PORTION_SIZE = 10.0      # was 8.0
MAX_PORTION_SIZE = 500.0     # was 600.0
MAX_ITERATIONS = 200         # was 300
LEARNING_RATE = 0.5          # was 0.3
CONVERGENCE_PATIENCE = 30    # remove early stopping
NUM_RESTARTS = 1             # was 2
```

## Key Files Modified

- `app/services/meal_plan_generator.rb` - Constants (lines 10-16) and `optimize_portions` method (lines 335-445)
- `docs/algorithm-improvements.md` - Full technical details
- `docs/algorithm-optimization.md` - Why algorithm struggles (unchanged)
