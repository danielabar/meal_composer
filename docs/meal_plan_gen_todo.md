# Meal Plan Generation TODOs

- plan show: also show/link to macro target and meal structure (a few more details mini view to remind user what it was)
- edge case: don't allow deletion of meal structures or macro targets that are in use by plan(s)
  - nicer: show which plans and offer to delete plans as well - modal experience
- edge case: what should happen if user edits a meal structure or macro target that is used in a plan - regenerate plan?
  - if fails, leave original plan?
- let user specify how many days to generate? but everything is only daily based...
- let user specify tolerance (overall? per macro?) - need to modify plan schema/model
- edit a plan, at the very least the title
- swap a food (finds another one at random from that category)
- replace a food with something specific - calculate amount based on holding everything else in the plan fixed
- failure case - plan could not be generated - what happens
