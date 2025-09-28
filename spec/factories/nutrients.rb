FactoryBot.define do
  factory :nutrient do
    sequence(:name) { |n| "Nutrient #{n}" }
    unit_name { "G" }
    sequence(:rank) { |n| n.to_f }
  end
end
