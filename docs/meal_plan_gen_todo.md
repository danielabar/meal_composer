# Meal Plan Generation TODOs

- Show calories on Daily Macro Summary on meal plan show view
- plan show: also show/link to macro target and meal structure (a few more details mini view to remind user what it was)

- instead of categories, allow food selection
- swap a food (finds another one at random from that category)
- replace a food with something specific - calculate amount based on holding everything else in the plan fixed

- `Generated 4 days ago` needs to update to use updated_at instead of created_at (or regenerate not updating updated_at date?)

- let user specify tolerance (overall? per macro?) - need to modify plan schema/model
- if plan is way off from tolerance - should that really be considered successfully generated? Maybe fail if not within tolerance?

- edge case: don't allow deletion of meal structures or macro targets that are in use by plan(s)
  - nicer: show which plans and offer to delete plans as well - modal experience
- edge case: what should happen if user edits a meal structure or macro target that is used in a plan?
  - user can regenerate the plan but maybe UI should tell them or somehow navigate them there to regenerate?
  - or modal showing all impacted plans with regenerate button next to each one or regenerate all?
- let user specify how many days to generate? but everything is only daily based...
- edit a plan, at the very least the title
- showing order incorrectly in meal plan

## Potential Improvements in Optimization Algorithm?

Potential improvements you could experiment with:

Weighted error function - prioritize protein for athlete plans:

```ruby
# Weight protein error more heavily for high-protein targets
protein_weight = target_protein > 150 ? 2.0 : 1.0
total_error = carb_error**2 + (protein_error * protein_weight)**2 + fat_error**2
```

Macro-specific food selection - when protein is under-target, bias food selection toward lean proteins (chicken, fish, egg whites) instead of random selection
Two-phase optimization - first optimize for protein + carbs, then fine-tune fat with oils/dressings
