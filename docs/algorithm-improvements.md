# Algorithm Improvements: Experimental Optimization Enhancements

## Summary

Modified `app/services/meal_plan_generator.rb` with focused improvements to the gradient descent optimizer for better balance between speed and quality:

### 1. **Convergence Detection**
- **Before:** Always ran 200 iterations (wasted CPU if stuck in local minimum)
- **After:** Stops early if no improvement for 30 consecutive iterations
- **Benefit:** Faster computation; prevents wasting time when optimizer is stuck

**Implementation:**
```ruby
no_improvement_count += 1 if error not improving
break if no_improvement_count >= CONVERGENCE_PATIENCE  # 30 iterations
```

### 2. **Multiple Random Restarts**
- **Before:** Single attempt with equal portions (could start in bad local minimum)
- **After:** 2 restart attempts with randomized initial portion sizes
- **Benefit:** Higher chance of escaping local minima without excessive slowdown

**Implementation:**
```ruby
NUM_RESTARTS.times do |restart_num|
  if restart_num == 0
    portions = Array.new(n, 300.0 / n)  # First: equal portions
  else
    portions = Array.new(n) { random_value }  # Random: 200-400g total
  end
  # Run full optimization, keep best result across all restarts
end
```

### 3. **Reduced Learning Rate (Removed decay)**
- **Before:** Fixed learning rate = 0.5 (stable but could overshoot)
- **After:** Fixed learning rate = 0.3 (more conservative, less oscillation)
- **Removed:** Complex decay learning rate (was causing convergence issues)
- **Benefit:** Simpler, more stable convergence; prevents oscillation

**Implementation:**
```ruby
LEARNING_RATE = 0.3  # Conservative step size
portions[i] += LEARNING_RATE * gradient
```

## Parameter Changes

| Parameter | Before | After | Reason |
|-----------|--------|-------|--------|
| `MIN_PORTION_SIZE` | 10.0g | 8.0g | More flexibility at lower end |
| `MAX_PORTION_SIZE` | 500.0g | 600.0g | More flexibility at upper end |
| `MAX_ITERATIONS` | 200 | 300 | Modest increase for better convergence |
| `LEARNING_RATE` | 0.5 | 0.3 | More conservative to prevent oscillation |
| `CONVERGENCE_PATIENCE` | N/A | 30 | New: stop if stuck for 30 iterations |
| `NUM_RESTARTS` | N/A | 2 | New: try 2 different starting points |

## Detailed Changes to `optimize_portions` Method

### Key Improvements:

1. **Outer loop:** `NUM_RESTARTS.times` - Try 2 different starting points
2. **Inner loop:** `MAX_ITERATIONS.times` - Run gradient descent up to 300 iterations
3. **Learning rate:** Fixed at 0.3 (conservative to prevent oscillation)
4. **Error calculation:** Simple squared error (back to basics, no weighting)
5. **Convergence detection:** Stops early if no improvement for 30 iterations
6. **Best tracking:** Keeps best result across all restarts

### Why This Approach:

- **Faster:** 2 restarts × ~150-300 iterations (with early stopping) ≈ 300-600 iterations total (vs 1500 before)
- **Simpler:** Removed complex decay learning rate logic
- **More stable:** Lower learning rate (0.3) reduces oscillation
- **Better escape:** Random restarts help find better solutions without exploding computation

## Expected Behavior

### What Should Improve:

1. **Plans that were borderline failing** - Random restarts find better starting points → better solutions
2. **Computation time** - Convergence detection stops when stuck, avoiding wasted iterations
3. **Wider variety of food portions** - Relaxed constraints (8-600g) allow more flexibility
4. **Overall stability** - Lower learning rate (0.3) prevents oscillation

### What Might Change:

- Slightly longer optimization time per meal (2 restarts, but with early stopping for faster exit)
- Plans might succeed/fail differently (different approach, new opportunities to escape local minima)
- Meal portions may be different from before (due to different starting points and search paths)

### What Should NOT Change:

- Plans that were already succeeding (should still succeed with similar portions)
- Plans that are mathematically impossible (will still fail after all attempts)
- Overall tolerance levels (8g standard, 16g relaxed, 32g last resort)

## Testing Instructions

1. **Regenerate Plan #13** ("Strict Keto + Leftovers From Mother-in-law")
   - Before: Protein 41g / Target 60g (failed to meet target)
   - Expected: Should be closer to 60g now (ideally within 8g)

2. **Try creating new plans** with:
   - High protein targets (100+g)
   - Restrictive food selections
   - Mix of high/low macro density foods

3. **Watch Rails logs** for optimization details:
   ```bash
   tail -f log/development.log | grep MealPlanGenerator
   ```

4. **Monitor performance:**
   - Should be faster for plans that converge early
   - May be slower for plans requiring multiple restarts

## Fallback & Rollback

If the improvements cause issues:

1. **To disable weighted error:** Change `protein_weight = 1.0` (always)
2. **To disable restarts:** Change `NUM_RESTARTS = 1`
3. **To go back to fast version:** Revert `MAX_ITERATIONS = 200`
4. **To debug:** Enable more verbose logging or reduce `CONVERGENCE_PATIENCE` threshold

## Notes

- This is **experimental** - no automated tests exist yet
- The improvements are **additive** - they work together
- Early testing should focus on edge cases (high protein, many foods, restrictive targets)
- Consider adding unit tests after confirming behavior is desirable
