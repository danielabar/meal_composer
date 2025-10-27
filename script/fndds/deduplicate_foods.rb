#!/usr/bin/env ruby
#
# FNDDS Food Deduplication Script
# ================================
#
# WHAT THIS DOES:
# Removes redundant food variations from the cleaned FNDDS dataset, keeping only
# the most useful/generic version of each food.
#
# WHY THIS IS NEEDED:
# After category and pattern-based filtering, FNDDS still contains many redundant
# variations of the same food. However, there are rarely "plain" versions - instead
# we need to intelligently select the MOST GENERIC variant.
#
# STRATEGY:
# Rather than blindly removing patterns, we:
#   1. Group foods by base name (e.g., all "Chicken breast*" together)
#   2. Rank each variant by "genericness" (NS as to > specific methods)
#   3. Keep only the most generic variants from each group
#
# EXAMPLES:
#   Chicken breast group:
#     KEEP: "Chicken breast, NS as to cooking method, skin not eaten" (generic)
#     KEEP: "Chicken breast, NS as to cooking method, skin eaten" (generic alternative)
#     REMOVE: "Chicken breast, baked, broiled, or roasted, skin not eaten" (specific method)
#     REMOVE: "Chicken breast, fried, coated, from restaurant" (specific + restaurant)
#
#   Broccoli group:
#     KEEP: "Broccoli, raw" (simplest)
#     KEEP: "Broccoli, NS as to form, cooked" (generic cooked)
#     REMOVE: "Broccoli, fresh, cooked, no added fat" (too specific)
#     REMOVE: "Broccoli, frozen, cooked with butter" (too specific)
#
# USAGE:
#   ruby script/fndds/deduplicate_foods.rb
#
# INPUT:  db/data/fndds/food_clean.csv              (after category/pattern filtering)
# OUTPUT: db/data/fndds/food_deduplicated.csv       (final clean food list)
#         db/data/fndds/food_removed_duplicates.csv (what was removed, for review)

require 'csv'

# File paths
INPUT_CSV  = File.expand_path('../../db/data/fndds/food_clean.csv', __dir__)
OUTPUT_CSV = File.expand_path('../../db/data/fndds/food_deduplicated.csv', __dir__)
REMOVED_CSV = File.expand_path('../../db/data/fndds/food_removed_duplicates.csv', __dir__)

# EXCLUSION PATTERNS - Applied before grouping
# These patterns identify foods we NEVER want, regardless of grouping
ALWAYS_EXCLUDE_PATTERNS = [
  # Restaurant/fast food (nutrition varies, not for home cooking)
  /\bfrom restaurant\b/i,
  /\bfrom fast food\b/i,
  /\bfast food\b/i,

  # With sauce/marinade (we want plain foods, users add their own)
  /\bwith sauce\b/i,
  /\bwith marinade\b/i,
  /\bin sauce\b/i,

  # Fried/breaded/coated (too processed)
  /\bfried, coated\b/i,
  /\bbreaded\b/i,
  /\bbattered\b/i,
  /\bcoating eaten\b/i,
  /\bcoating not eaten\b/i,

  # "As ingredient" variants (for recipes, not direct consumption)
  /\bas ingredient$/i,

  # Combination foods (we want single ingredients)
  # Must have comma before "and/or" to avoid false positives like "almond milk"
  /,\s+\w+\s+and\s+/i,  # "broccoli, carrots and cauliflower"
  /,\s+\w+\s+or\s+/i,   # "chicken, turkey or duck"

  # From pre-cooked (prefer raw/fresh)
  /\bfrom pre-?cooked\b/i,

  # Canned/pickled (prefer fresh)
  /\bcanned\b/i,
  /\bpickled\b/i,

  # Specific fat additions (users will add their own)
  /\bwith oil\b/i,
  /\bwith butter\b/i,
  /\bwith margarine\b/i,
]

# SCORING SYSTEM - Lower score = more generic = better
# We'll score each food variant and keep the lowest-scoring ones
def score_food(description)
  score = 0

  # PENALTY: Specific cooking methods (we prefer "NS as to cooking method")
  score += 10 if description.match?(/\b(baked|broiled|roasted|grilled|sauteed|stewed|boiled|steamed|microwaved)\b/i)

  # PENALTY: Rotisserie (specific preparation)
  score += 10 if description.match?(/\brotisserie\b/i)

  # PENALTY: Fresh/frozen specificity (prefer generic)
  score += 5 if description.match?(/\bfresh,/i)
  score += 5 if description.match?(/\bfrozen,/i)

  # PENALTY: Fat specifications
  score += 5 if description.match?(/\bfat added\b/i)
  score += 5 if description.match?(/\bno added fat\b/i)

  # PENALTY: "from raw" (prefer unspecified)
  score += 3 if description.match?(/\bfrom raw\b/i)

  # PENALTY: Reduced fat/low sodium variations
  score += 8 if description.match?(/\breduced fat\b/i)
  score += 8 if description.match?(/\blow fat\b/i)
  score += 8 if description.match?(/\blowfat\b/i)
  score += 8 if description.match?(/\bnonfat\b/i)
  score += 8 if description.match?(/\blow sodium\b/i)

  # BONUS: "NS as to" makes it MORE generic (reduce score)
  score -= 20 if description.match?(/\bNS as to\b/i)

  # BONUS: "NFS" or standalone "NS" (generic)
  score -= 15 if description.match?(/\bNFS\b/i)
  score -= 10 if description.match?(/\bNS\b/i) && !description.match?(/\bNS as to\b/i)

  # BONUS: Very short descriptions are often simpler
  score -= 5 if description.length < 30

  # BONUS: "raw" for vegetables (simple, common)
  score -= 10 if description.match?(/,\s*raw$/i)

  score
end

# Extract base food name for grouping
# "Chicken breast, NS as to cooking method, skin eaten" -> "Chicken breast"
# "Broccoli, fresh, cooked, no added fat" -> "Broccoli"
# "Fish, salmon, NFS" -> "Fish, salmon"
# "Fish, catfish, baked or broiled" -> "Fish, catfish"
def extract_base_name(description)
  parts = description.split(',').map(&:strip)

  # Special case: Foods that start with "Fish," need TWO parts to identify the species
  # "Fish, salmon, NFS" -> "Fish, salmon" (not just "Fish")
  if parts[0] == "Fish" && parts.size >= 2
    base = "#{parts[0]}, #{parts[1]}"
  else
    # Standard case: Take everything before the first comma (or the whole thing if no comma)
    base = parts[0]
  end

  # Normalize whitespace
  base.gsub(/\s+/, ' ').strip
end

# Process the CSV
puts "FNDDS Food Deduplication (Smart Grouping)"
puts "=" * 70
puts "Input:  #{INPUT_CSV}"
puts "Output: #{OUTPUT_CSV}"
puts ""

unless File.exist?(INPUT_CSV)
  puts "❌ Error: Input file not found: #{INPUT_CSV}"
  puts "   Run extract_clean_foods.rb first."
  exit 1
end

puts "Reading clean food CSV..."
rows = CSV.read(INPUT_CSV, headers: true)
puts "  Total foods after cleanup: #{rows.size}"

# Step 1: Filter out always-excluded patterns
puts "\nStep 1: Applying always-exclude patterns..."
filtered_rows = []
always_excluded_rows = []

rows.each do |row|
  description = row['description'].to_s

  if ALWAYS_EXCLUDE_PATTERNS.any? { |pattern| description.match?(pattern) }
    always_excluded_rows << row
  else
    filtered_rows << row
  end
end

puts "  Excluded by patterns: #{always_excluded_rows.size}"
puts "  Remaining for grouping: #{filtered_rows.size}"

# Step 2: Group foods by base name AND category
# Important: Foods in different FNDDS categories should NOT be grouped together
# (e.g., "Milk, whole" in category 1002 vs "Milk, nonfat" in category 1008)
puts "\nStep 2: Grouping foods by base name and category..."
groups = Hash.new { |h, k| h[k] = [] }

filtered_rows.each do |row|
  base_name = extract_base_name(row['description'])
  category_id = row['food_category_id']
  # Use both base name and category as the grouping key
  group_key = "#{base_name}|#{category_id}"
  groups[group_key] << row
end

puts "  Found #{groups.size} unique base foods"
multi_variant_groups = groups.select { |_, variants| variants.size > 1 }
puts "  #{multi_variant_groups.size} foods have multiple variants"

# Step 3: Select best variants from each group
puts "\nStep 3: Selecting best variants from each group..."
kept_rows = []
dedup_excluded_rows = []

groups.each do |base_name, variants|
  if variants.size == 1
    # Only one variant, keep it
    kept_rows << variants.first
  else
    # Multiple variants - score them and keep the best ones
    scored_variants = variants.map do |row|
      score = score_food(row['description'])
      { row: row, score: score, description: row['description'] }
    end

    # Sort by score (lower = better)
    scored_variants.sort_by! { |v| v[:score] }

    # Strategy: Keep up to 3 best variants (to preserve skin eaten/not eaten options, etc.)
    # But only if they're reasonably close in score
    best_score = scored_variants.first[:score]
    keep_count = 0

    scored_variants.each do |variant|
      # Keep if it's one of the top 3 AND within 15 points of the best score
      if keep_count < 3 && (variant[:score] - best_score) <= 15
        kept_rows << variant[:row]
        keep_count += 1
      else
        dedup_excluded_rows << variant[:row]
      end
    end
  end
end

puts "  Kept: #{kept_rows.size} foods"
puts "  Excluded by deduplication: #{dedup_excluded_rows.size}"

# Combine all excluded rows
all_excluded_rows = always_excluded_rows + dedup_excluded_rows

# Step 4: Write output files
puts "\nStep 4: Writing output files..."

# Write deduplicated CSV
CSV.open(OUTPUT_CSV, 'w', write_headers: true, headers: rows.headers) do |csv|
  kept_rows.each { |row| csv << row }
end
puts "  ✅ Wrote #{kept_rows.size} foods to #{OUTPUT_CSV}"

# Write removed duplicates CSV for review
CSV.open(REMOVED_CSV, 'w', write_headers: true, headers: rows.headers) do |csv|
  all_excluded_rows.each { |row| csv << row }
end
puts "  ✅ Wrote #{all_excluded_rows.size} removed foods to #{REMOVED_CSV}"

# Summary
total_removed = all_excluded_rows.size
removal_pct = (total_removed.to_f / rows.size * 100).round(1)

puts ""
puts "=" * 70
puts "✅ Smart deduplication complete!"
puts ""
puts "Results:"
puts "  Input foods:              #{rows.size}"
puts "  Output foods:             #{kept_rows.size}"
puts "  Removed (always-exclude): #{always_excluded_rows.size}"
puts "  Removed (deduplication):  #{dedup_excluded_rows.size}"
puts "  Total removed:            #{total_removed} (#{removal_pct}%)"
puts ""
puts "Strategy:"
puts "  - Grouped foods by base name (e.g., 'Chicken breast')"
puts "  - Scored each variant by genericness"
puts "  - Kept up to 3 most generic variants per group"
puts "  - Always excluded: restaurant, with sauce, fried/coated, combinations"
puts ""
puts "Next steps:"
puts "  1. Review #{REMOVED_CSV} to verify correct foods were removed"
puts "  2. Run: ruby script/fndds/extract_clean_food_nutrients.rb"
puts ""
