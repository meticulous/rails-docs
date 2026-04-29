Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"

  scope ":version", constraints: { version: /v[\d\.]+|edge/ } do
    get "*path",
        to: "entities#show",
        as: :entity,
        format: false,
        constraints: { path: %r{[^?]+} }
  end
end
