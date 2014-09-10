require 'spec_helper'

feature 'Viewing my agreements and signatures' do

  scenario 'as a signed out user' do
    visit '/sign_out'
    page.should_not have_content('My agreements and signatures')
  end

  scenario 'as a signed in user with agreements and signatures' do
    jasonm = create(:user, nickname: 'jasonm')
    alice = create(:user, nickname: 'alice')

    create(:agreement, user: jasonm, user_name: 'jasonm', repo_name: 'jam')
    create(:agreement, user: jasonm, user_name: 'jasonm', repo_name: 'jelly')
    create(:agreement, user: alice, user_name: 'alice', repo_name: 'anodyne')
    create(:agreement, user: alice, user_name: 'alice', repo_name: 'airmattress')

    mock_github_oauth(info: { nickname: 'jasonm' }, credentials: { token: 'token' }, uid: github_uid_for_nickname('jasonm'))
    mock_github_user_repos(oauth_token: 'token', repos: [])
    mock_github_user_orgs(oauth_token: 'token', orgs: [])

    visit '/'
    click_link 'Sign in with GitHub to get started'
    click_link 'My agreements and signatures'
    page.should have_content 'jam'
    page.should have_content 'jelly'
    page.should_not have_content('anodyne')
    page.should_not have_content('airmattress')
    page.should have_content("You haven't signed any agreements.")

    create(:signature, user: jasonm, agreement: Agreement.find_by_user_name_and_repo_name('alice', 'anodyne'))
    create(:signature, user: jasonm, agreement: Agreement.find_by_user_name_and_repo_name('alice', 'airmattress'))
    click_link 'My agreements and signatures'
    page.should have_content('anodyne')
    page.should have_content('airmattress')
  end

  feature 'when an ADMIN_REPO has been defined' do
    before {
      ADMIN_REPO = 'strongloop/clahub'
    }
    after {
      ADMIN_REPO = false
    }
    scenario 'as a signed in user who collaborates on ADMIN_REPO' do
      expect(ADMIN_REPO).to eq('strongloop/clahub')
      mock_github_repo_collaborator(owner: 'strongloop', repo: 'clahub', user: 'jasonm', oauth_token: 'token')
      jasonm = create(:user, nickname: 'jasonm')
      alice = create(:user, nickname: 'alice')

      create(:agreement, user: jasonm, user_name: 'jasonm', repo_name: 'jam')
      create(:agreement, user: jasonm, user_name: 'jasonm', repo_name: 'jelly')
      create(:agreement, user: alice, user_name: 'alice', repo_name: 'anodyne')
      create(:agreement, user: alice, user_name: 'alice', repo_name: 'airmattress')

      mock_github_oauth(info: { nickname: 'jasonm' }, credentials: { token: 'token' }, uid: github_uid_for_nickname('jasonm'))
      mock_github_user_repos(oauth_token: 'token', repos: [])
      mock_github_user_orgs(oauth_token: 'token', orgs: [])

      visit '/'
      click_link 'Sign in with GitHub to get started'
      click_link 'My agreements and signatures'
      page.should have_content 'jam'
      page.should have_content 'jelly'
      page.should_not have_content('anodyne')
      page.should_not have_content('airmattress')
      page.should have_content("You haven't signed any agreements.")

      create(:signature, user: jasonm, agreement: Agreement.find_by_user_name_and_repo_name('alice', 'anodyne'))
      create(:signature, user: jasonm, agreement: Agreement.find_by_user_name_and_repo_name('alice', 'airmattress'))
      click_link 'My agreements and signatures'
      page.should have_content('anodyne')
      page.should have_content('airmattress')
    end

    scenario 'as a signed in user who IS NOT a collaborator on ADMIN_REPO' do
      expect(ADMIN_REPO).to eq('strongloop/clahub')
      mock_github_repo_not_collaborator(owner: 'strongloop', repo: 'clahub', user: 'jasonm', oauth_token: 'token')
      jasonm = create(:user, nickname: 'jasonm')
      alice = create(:user, nickname: 'alice')

      create(:agreement, user: jasonm, user_name: 'jasonm', repo_name: 'jam')
      create(:agreement, user: jasonm, user_name: 'jasonm', repo_name: 'jelly')
      create(:agreement, user: alice, user_name: 'alice', repo_name: 'anodyne')
      create(:agreement, user: alice, user_name: 'alice', repo_name: 'airmattress')

      mock_github_oauth(info: { nickname: 'jasonm' }, credentials: { token: 'token' }, uid: github_uid_for_nickname('jasonm'))
      mock_github_user_repos(oauth_token: 'token', repos: [])
      mock_github_user_orgs(oauth_token: 'token', orgs: [])

      visit '/'
      click_link 'Sign in with GitHub to get started'
      click_link 'My agreements and signatures'
      page.should_not have_content 'jam'
      page.should_not have_content 'jelly'
      page.should_not have_content('anodyne')
      page.should_not have_content('airmattress')
      page.should have_content("You haven't signed any agreements.")
      page.should_not have_content("Create a new agreement")

      create(:signature, user: jasonm, agreement: Agreement.find_by_user_name_and_repo_name('alice', 'anodyne'))
      create(:signature, user: jasonm, agreement: Agreement.find_by_user_name_and_repo_name('alice', 'airmattress'))
      click_link 'My agreements and signatures'
      page.should have_content('anodyne')
      page.should have_content('airmattress')
    end
  end

end
