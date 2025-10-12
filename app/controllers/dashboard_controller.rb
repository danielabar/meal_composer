class DashboardController < ApplicationController
  # Require authentication for all actions in this controller
  before_action :require_authentication

  def index
    # This will be the main dashboard after login
    @user = Current.user
  end
end
