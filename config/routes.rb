Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"

  get "/search", to: "search#index", as: :search
  get "/search/suggest", to: "search#suggest", as: :search_suggest, defaults: { format: :json }
  get "/sitemap.xml", to: "sitemaps#index", as: :sitemap, defaults: { format: :xml }
  get "/feeds/:framework_slug", to: "feeds#framework", as: :framework_feed, defaults: { format: :atom }

  # Legacy sdoc URL shapes — 301 to the current stable equivalent.
  get "/classes/*sdoc_path", to: "legacy_redirects#class_show", format: false
  get "/files/*sdoc_path", to: "legacy_redirects#file_show", format: false
  get "/_legacy_method", to: "legacy_redirects#method_redirect"

  scope ":version", constraints: { version: /v[\d\.]+|edge/ } do
    get "/", to: "versions#show", as: :version
    get "/sitemap.xml", to: "sitemaps#show", as: :version_sitemap, defaults: { format: :xml }
    get "/og/*path", to: "og_images#show", as: :og_image, defaults: { format: :svg }, constraints: { path: %r{[^?]+} }
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
