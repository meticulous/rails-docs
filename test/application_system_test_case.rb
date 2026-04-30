require "test_helper"

# Capybara default driver (Selenium + headless Chrome) for now. The plan calls
# for capybara-playwright-driver as the long-term choice; swap by changing
# the driven_by line below — no test edits needed.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]
end
