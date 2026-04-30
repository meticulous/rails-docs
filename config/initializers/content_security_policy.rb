# Application-wide Content Security Policy. Locked-down by default,
# with nonces auto-applied to importmap script tags and our JSON-LD
# blocks. The schema:
#
#   default-src     'none'             — block by default; allow per-type
#   script-src      'self' 'nonce-...' — self-hosted JS + nonce'd inline
#   style-src       'self' 'nonce-...' — self-hosted CSS + nonce'd inline
#   img-src         'self' data:       — self-hosted + data: (inline SVG)
#   font-src        'self'             — self-hosted only
#   connect-src     'self'             — XHR/fetch to /search/suggest.json
#   form-action     'self'             — form posts to our endpoints only
#   base-uri        'self'             — prevent <base> hijacking
#   frame-ancestors 'none'             — block embedding (clickjacking)
#   object-src      'none'             — no Flash / object plugins
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src     :none
    policy.script_src      :self
    policy.style_src       :self
    policy.img_src         :self, :data
    policy.font_src        :self
    policy.connect_src     :self
    policy.form_action     :self
    policy.base_uri        :self
    policy.frame_ancestors :none
    policy.object_src      :none
  end

  # Nonce generator + the directives that opt into nonces. Rails will
  # auto-apply the nonce to importmap and javascript_tag output; we
  # also pull it through to our JSON-LD partial via `content_security_policy_nonce`.
  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
end
