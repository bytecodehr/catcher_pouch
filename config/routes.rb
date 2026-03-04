# frozen_string_literal: true

CatcherPouch::Engine.routes.draw do
  root to: 'mailers#index'

  resources :mailers, only: [:index], param: :mailer_class do
    member do
      get :show, path: ''
    end
  end

  get  'templates/show',    to: 'templates#show',    as: :template_show
  get  'templates/preview', to: 'templates#preview', as: :template_preview
  patch 'templates/update', to: 'templates#update',  as: :template_update
end
