class FoodSearchesController < ApplicationController
  before_action :require_authentication

  def index
    query = params[:q].presence || ""
    page = (params[:page] || 1).to_i
    limit = 20
    offset = (page - 1) * limit

    # Build base query
    base_query = if query.blank?
      Food.order(:description)
    else
      Food.where("description ILIKE ?", "%#{query}%")
          .order(:description)
    end

    # Get total count for pagination
    total_count = base_query.count

    # Get paginated results
    foods = base_query.offset(offset).limit(limit)

    render json: {
      foods: foods.map { |f| { id: f.id, description: f.description } },
      total_count: total_count,
      page: page,
      per_page: limit
    }
  end
end
