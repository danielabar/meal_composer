class FoodSearchesController < ApplicationController
  before_action :require_authentication

  def index
    query = params[:q].presence || ""
    limit = 20

    foods = if query.blank?
              Food.order(:description).limit(limit)
            else
              Food.where("description ILIKE ?", "%#{query}%")
                  .order(:description)
                  .limit(limit)
            end

    render json: foods.map { |f| { id: f.id, description: f.description } }
  end
end
