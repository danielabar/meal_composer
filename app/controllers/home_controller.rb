class HomeController < ApplicationController
  # Allow unauthenticated access to home page
  allow_unauthenticated_access

  def index
    # Redirect to dashboard if user is already logged in
    if authenticated?
      redirect_to dashboard_path
    end
  end
end
