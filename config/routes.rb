Rails.application.routes.draw do
  root "home#index"
  resources :accounts, only: [:index, :show]
  resources :statements, only: [:new, :create]
end
