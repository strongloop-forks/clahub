require 'digest/md5'

module GithubMockHelpers
  def set_default_github_oauth_options(options)
    options[:uid] ||= '12345'
    options[:info] ||= {}
    options[:info][:email] ||= 'jason.p.morrison@gmail.com'
    options[:info][:name] ||= 'Jason Morrison'
    options[:info][:nickname] ||= 'jasonm'
    options[:credentials] ||= {}
    options[:credentials][:token] ||= 'token-abcdef123456'
  end

  def mock_github_oauth(options={})
    set_default_github_oauth_options(options)
    OmniAuth.config.add_mock(:github, options)
    OmniAuth.config.test_mode = true
  end

  def mock_github_limited_oauth(options={})
    set_default_github_oauth_options(options)
    OmniAuth.config.add_mock(:github_limited, options)
    OmniAuth.config.test_mode = true
  end

  def mock_github_oauth_failure(failure_message = :access_denied)
    OmniAuth.config.mock_auth[:github] = failure_message
    OmniAuth.config.test_mode = true
  end

  def mock_github_user_repos(options={})
    assert_options(options, :oauth_token, :repos)

    json_response = options[:repos].to_json
    stub_request(:get, "https://api.github.com/user/repos")
      .with(headers: { 'Authorization' => "token #{options[:oauth_token]}" })
      .to_return(status: 200, body: json_response, headers: { 'Content-Type' => 'application/vnd.github.v3+json' })
  end

  def mock_github_repo_hook(options={})
    assert_options(options, :oauth_token, :user_name, :repo_name, :resulting_hook_id)

    json_response = { url: 'http://something', id: options[:resulting_hook_id] }.to_json
    stub_request(:post, "https://api.github.com/repos/#{options[:user_name]}/#{options[:repo_name]}/hooks")
      .with(headers: { 'Authorization' => "token #{options[:oauth_token]}" })
      .to_return(status: 201, body: json_response, headers: { 'Content-Type' => 'application/vnd.github.v3+json' })
  end

  def mock_github_set_commit_status(options={})
    assert_options(options, :user_name, :repo_name, :sha)
    options[:oauth_token] ||= oauth_token_for(options[:user_name])

    json_response = options[:json_response] || { whatever: 'yeah' }.to_json
    url = "https://api.github.com/repos/#{options[:user_name]}/#{options[:repo_name]}/statuses/#{options[:sha]}"
    stub_request(:post, url)
    .with(headers: { 'Authorization' => "token #{options[:oauth_token]}" })
    .to_return(status: 201, body: json_response, headers: { 'Content-Type' => 'application/vnd.github.v3+json' })
  end

  # TODO refactor other mocks and default oauth_token based on owner/user_name where appropriate
  def mock_github_open_pulls(options = {})
    assert_options(options, :owner, :repo, :pull_ids)
    options[:oauth_token] ||= oauth_token_for(options[:owner])

    attributes_for_open_pulls = options[:pull_ids].map { |id|
      { "number" => id }
    }

    json_response = attributes_for_open_pulls.to_json
    url = "https://api.github.com/repos/#{options[:owner]}/#{options[:repo]}/pulls"
    stub_request(:get, url)
      .with(headers: { 'Authorization' => "token #{options[:oauth_token]}" })
      .to_return(status: 200, body: json_response,
      headers: { 'Content-Type' => 'application/vnd.github.v3+json' })
  end

  # options[:commits] is an array of hashes,
  # each hash can contain keys :committer, :author, :sha, :url, :commit{}
  def mock_github_pull_commits(options = {})
    assert_options(options, :owner, :repo, :pull_id, :commits)
    assert_options_array(options[:commits], :author, :sha)
    options[:oauth_token] ||= oauth_token_for(options[:owner])

    json_response = options[:commits].to_json
    url = "https://api.github.com/repos/#{options[:owner]}/#{options[:repo]}/pulls/#{options[:pull_id]}/commits"
    stub_request(:get, url)
      .with(headers: { 'Authorization' => "token #{options[:oauth_token]}" })
      .to_return(status: 200, body: json_response,
      headers: { 'Content-Type' => 'application/vnd.github.v3+json' })
  end

  def mock_github_repo_collaborator(options = {})
    assert_options(options, :owner, :repo, :user)
    options[:oauth_token] ||= oauth_token_for(options[:user])
    set_default_github_oauth_options(options)

    json_response = options[:commits].to_json
    url = "https://api.github.com/repos/#{options[:owner]}/#{options[:repo]}/collaborators/#{options[:user]}" #{}"?access_token=#{options[:oauth_token]}"
    # stub_request(:get, "https://api.github.com/user/repos")
    #   .with(headers: {
    #     'Authorization'=> "token #{options[:oauth_token]}",
    #   })
    #   .to_return(status: 200, body: "[]", headers: {})
    stub_request(:get, url)
      .with(headers: { 'Authorization' => "token #{options[:oauth_token]}" })
      .to_return(status: 204)
  end

  def mock_github_repo_not_collaborator(options = {})
    assert_options(options, :owner, :repo, :user)
    set_default_github_oauth_options(options)
    options[:oauth_token] ||= options[:credentials][:token]
    #||= oauth_token_for(options[:user])

    json_response = options[:commits].to_json
    url = "https://api.github.com/repos/#{options[:owner]}/#{options[:repo]}/collaborators/#{options[:user]}" #{}"?access_token=#{options[:oauth_token]}"
    # stub_request(:get, "https://api.github.com/user/repos")
    #   .with(headers: {
    #     # 'Accept'=> 'application/vnd.github.v3+json',
    #     # 'Accept-Encoding'=> 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
    #     'Authorization'=> "token #{options[:oauth_token]}",
    #     # 'Content-Type'=> 'application/json',
    #     # 'User-Agent'=> 'Octokit Ruby Gem 3.7.0'
    #   })
    #   .to_return(status: 200, body: "[]", headers: {})
    stub_request(:get, url)
      .with(headers: { 'Authorization' => "token #{options[:oauth_token]}" })
      .to_return(status: 404)
  end

  def mock_github_user_orgs(options = {})
    assert_options(options, :oauth_token, :orgs)
    assert_options_array(options[:orgs], :login)

    json_response = options[:orgs].to_json
    url = "https://api.github.com/user/orgs"
    stub_request(:get, url)
      .with(headers: { 'Authorization' => "token #{options[:oauth_token]}" })
      .to_return(status: 200, body: json_response, headers: { 'Content-Type' => 'application/vnd.github.v3+json' })
  end

  def mock_github_org_repos(options = {})
    assert_options(options, :oauth_token, :org, :repos)
    assert_options_array(options[:repos], :name, :permissions)

    json_response = options[:repos].to_json
    url = "https://api.github.com/users/#{options[:org]}/repos"
    stub_request(:get, url)
      .with(headers: { 'Authorization' => "token #{options[:oauth_token]}" })
      .to_return(status: 200, body: json_response, headers: { 'Content-Type' => 'application/vnd.github.v3+json' })
  end

  def github_uid_for_nickname(nickname)
    # consistent and unique-enough string-to-4-byte-integer mapping
    User.find_by_nickname(nickname).try(:uid) || nickname.hash.abs.to_s[0..8].to_i
  end

  def oauth_token_for(nickname)
    User.find_by_nickname(nickname).try(:oauth_token) || Digest::MD5.hexdigest(nickname)
  end

  private

  def assert_options(options, *required_keys)
    required_keys.each do |key|
      raise "must include :#{key}" unless options[key]
    end
  end

  def assert_options_array(options_array, *required_keys)
    raise "options must include array but did not" unless options_array.is_a?(Array)
    options_array.each do |options|
      assert_options(options, *required_keys)
    end
  end
end
