require 'spec_helper'

feature "Splash page" do
  scenario "Explains the site to a visitor" do
    visit '/'
    page.should have_content('Thank you for your interest')
    page.should have_content('GitHub')
  end
end
