Rails.application.routes.draw do
  # Source slugs are an optional first segment so /v8.1.2/... continues
  # to route to rails (no canonical break) while /turbo-rails/v2.0.16/...
  # routes to the same controllers with current_source flipped. The
  # :version regex below is what disambiguates the two; anything else in
  # the slug position falls through to ApplicationController#current_source
  # and 404s if it isn't a known Source.
  get "up" => "rails/health#show", as: :rails_health_check
  get "health" => "health#show", as: :health_check

  root "home#index"

  get "/search", to: "search#index", as: :search
  get "/search/suggest", to: "search#suggest", as: :search_suggest, defaults: { format: :json }
  get "/sitemap.xml", to: "sitemaps#index", as: :sitemap, defaults: { format: :xml }
  get "/feeds/:framework_slug", to: "feeds#framework", as: :framework_feed, defaults: { format: :atom }
  get "/feeds/sources/:source_slug", to: "feeds#source", as: :source_feed, defaults: { format: :atom }

  get "/ecosystem", to: "ecosystem#index", as: :ecosystem

  # Legacy sdoc URL shapes — 301 to the current stable equivalent.
  get "/classes/*sdoc_path", to: "legacy_redirects#class_show", format: false
  get "/files/*sdoc_path", to: "legacy_redirects#file_show", format: false
  get "/_legacy_method", to: "legacy_redirects#method_redirect"

  post "/webhooks/ingest", to: "webhooks#ingest"

  scope "(/:source_slug)" do
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
end
