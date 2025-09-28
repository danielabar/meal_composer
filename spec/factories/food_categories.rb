FactoryBot.define do
  factory :food_category do
    sequence(:code) { |n| "CATEGORY_#{n}" }
    sequence(:description) { |n| "Food Category #{n}" }
  end
end
