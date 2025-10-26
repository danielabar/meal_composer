puts "🧑 Seeding development user data..."

# Create development user
user = User.find_or_create_by!(email_address: "user@example.com") do |u|
  u.password = "password"
end
puts "  ✅ User: #{user.email_address}"

# Seed sample macro targets for testing
strict_keto = DailyMacroTarget.find_or_create_by!(user: user, name: "Strict Keto") do |target|
  target.carbs_grams = 20
  target.protein_grams = 60
  target.fat_grams = 180
end
puts "  ✅ Macro Target: #{strict_keto.name}"

high_protein = DailyMacroTarget.find_or_create_by!(user: user, name: "High Protein Athlete") do |target|
  target.carbs_grams = 250
  target.protein_grams = 180
  target.fat_grams = 70
end
puts "  ✅ Macro Target: #{high_protein.name}"

puts "🎉 Development user data seeded!"
