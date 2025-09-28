FactoryBot.define do
  factory :food_nutrient do
    sequence(:fdc_id) { |n| n }
    association :nutrient
    amount { 10.5 }
  end
end
