# frozen_string_literal: true

Rails.application.routes.draw do
  post '/purchases', to: 'purchases#create'
end
