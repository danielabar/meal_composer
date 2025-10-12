# This data is needed in all environments
dataset = ENV["DATASET"] || "foundation"
if dataset == "foundation"
  load Rails.root.join("db/seeds_foundation.rb")
elsif dataset == "fndds"
  load Rails.root.join("db/seeds_fndds.rb")
else
  puts "❌ Invalid dataset specified. Use DATASET=foundation or DATASET=fndds"
  exit 1
end

# This is only for development
if Rails.env.development?
  User.find_or_create_by!(email_address: "user@example.com") do |user|
    user.password = "password"
  end
end
