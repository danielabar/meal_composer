# TODO: Unused?
class MealPreferences
  attr_reader :breakfast_categories, :lunch_categories, :dinner_categories

  def initialize(breakfast_categories:, lunch_categories:, dinner_categories:)
    @breakfast_categories = breakfast_categories
    @lunch_categories = lunch_categories
    @dinner_categories = dinner_categories
  end

  def categories_for_meal(meal_type)
    case meal_type
    when :breakfast then breakfast_categories
    when :lunch then lunch_categories
    when :dinner then dinner_categories
    else []
    end
  end
end
