# Default to FNDDS dataset, can be overridden with DATASET env var
dataset = ENV["DATASET"] || "fndds"

# This data is needed in all environments
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
  load Rails.root.join("db/seeds_development.rb")
end
