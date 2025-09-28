# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

## Try It

```ruby
macro_targets = MacroTargets.new(carbs: 50, protein: 100, fat: 150)
composer = DailyMealComposer.new
result = composer.compose_daily_meals(macro_targets: macro_targets)

if result.composed?
  plan = result.daily_plan
  puts "Success! Plan uses #{plan.total_foods} foods totaling #{plan.total_grams}g"
  puts "Target: #{plan.target_macros}"
  puts "Actual: #{plan.actual_macros}"
  puts "Within tolerance: #{plan.within_tolerance?}"

  puts "=== BREAKFAST ==="
  plan.breakfast.food_portions.each do |portion|
    puts "#{portion.grams.round(1)}g of #{portion.food.description}"
  end
  puts "Breakfast macros: carbs=#{plan.breakfast.macros.carbs.round(1)}g, protein=#{plan.breakfast.macros.protein.round(1)}g, fat=#{plan.breakfast.macros.fat.round(1)}g"
  puts

  puts "=== LUNCH ==="
  plan.lunch.food_portions.each do |portion|
    puts "#{portion.grams.round(1)}g of #{portion.food.description}"
  end
  puts "Lunch macros: carbs=#{plan.lunch.macros.carbs.round(1)}g, protein=#{plan.lunch.macros.protein.round(1)}g, fat=#{plan.lunch.macros.fat.round(1)}g"
  puts

  puts "=== DINNER ==="
  plan.dinner.food_portions.each do |portion|
    puts "#{portion.grams.round(1)}g of #{portion.food.description}"
  end
  puts "Dinner macros: carbs=#{plan.dinner.macros.carbs.round(1)}g, protein=#{plan.dinner.macros.protein.round(1)}g, fat=#{plan.dinner.macros.fat.round(1)}g"
  puts

  puts "=== DAILY TOTALS ==="
  puts "Target: #{plan.target_macros}"
  puts "Actual: #{plan.actual_macros}"
  puts "Difference: carbs #{(plan.actual_macros.carbs - plan.target_macros.carbs).round(1)}g, protein #{(plan.actual_macros.protein - plan.target_macros.protein).round(1)}g, fat #{(plan.actual_macros.fat - plan.target_macros.fat).round(1)}g"
  puts "Within tolerance: #{plan.within_tolerance?}"
else
  puts "Failed: #{result.error}"
end
```
