Rails.application.routes.draw do
  # Authentication routes (created by authentication generator)
  resource :session, only: [ :new, :create, :destroy ]
  resources :passwords, param: :token, only: [ :new, :create, :edit, :update ]

  # User registration
  resources :registrations, only: [ :new, :create ]

  # Dashboard (for authenticated users)
  get "dashboard", to: "dashboard#index"

  # Public home page
  root "home#index"

  resources :daily_macro_targets, except: [ :show ]
  resources :daily_meal_structures, except: [ :show ]

  # Health check endpoint
  get "up" => "rails/health#show", as: :rails_health_check

  # PWA files (if you enable PWA)
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
end
