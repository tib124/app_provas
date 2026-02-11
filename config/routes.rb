Rails.application.routes.draw do
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  get "dashboard" => "dashboard#show", as: :dashboard

  resources :alunos, only: %i[index new create edit update destroy]

  resources :provas, only: %i[index show new create edit update destroy] do
    get "gabarito" => "gabaritos#index", as: :gabarito

    resources :questoes, only: %i[index new create edit update destroy] do
      resource :gabarito, only: %i[new create edit update destroy]
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  authenticated :user do
    root "dashboard#show", as: :authenticated_root
  end
  root "pages#home"
end
