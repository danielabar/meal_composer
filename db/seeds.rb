dataset = ENV["DATASET"] || "foundation"

if dataset == "foundation"
  load Rails.root.join("db/seeds_foundation.rb")
elsif dataset == "fndds"
  load Rails.root.join("db/seeds_fndds.rb")
else
  puts "❌ Invalid dataset specified. Use DATASET=foundation or DATASET=fndds"
  exit 1
end
