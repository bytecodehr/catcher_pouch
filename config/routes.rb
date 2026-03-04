# frozen_string_literal: true

CatcherPouch::Engine.routes.draw do
  root to: 'mailers#index'

  resources :mailers, only: [:index], param: :mailer_class do
    member do
      get :show, path: ''
    end
  end

  resources :templates, only: [], param: :path do
    collection do
      get :show
      get :preview
      patch :update
    end
  end
end
