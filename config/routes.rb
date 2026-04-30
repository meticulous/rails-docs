Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"

  get "/search", to: "search#index", as: :search
  get "/sitemap.xml", to: "sitemaps#index", as: :sitemap, defaults: { format: :xml }

  scope ":version", constraints: { version: /v[\d\.]+|edge/ } do
    get "/sitemap.xml", to: "sitemaps#show", as: :version_sitemap, defaults: { format: :xml }
    get "*entity_path/-/diff/:other_version",
        to: "diffs#show",
        as: :diff,
        format: false,
        constraints: { entity_path: %r{[^?]+}, other_version: /v[\d\.]+|edge/ }
    get "*path",
        to: "entities#show",
        as: :entity,
        format: false,
        constraints: { path: %r{[^?]+} }
  end
end
