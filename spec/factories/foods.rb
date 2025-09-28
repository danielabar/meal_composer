FactoryBot.define do
  factory :food do
    sequence(:fdc_id) { |n| n }
    sequence(:description) { |n| "Food Item #{n}" }
    association :food_category
    publication_date { Date.current }
  end
end
