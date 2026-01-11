# frozen_string_literal: true

require "test_helper"
require "capybara/rails"

class QuoteFlowTest < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :chrome, screen_size: [ 1400, 1400 ]

  test "complete quote flow" do
    visit new_quote_path

    fill_in "Age", with: "30"
    select "One Way", from: "Trip Type"
    # Fill other fields...

    click_button "Get quote"

    assert_selector ".premium-table"  # Your results table
    assert_text "$125.50"  # Sample premium
  end
end
