require 'spec_helper'

describe 'receiving github repo "Commit" webhook callbacks' do
  let(:token) { 'abc123' }

  before do
    mock_github_oauth(credentials: { token: token })
    mock_github_set_commit_status({ oauth_token: token, user_name: 'jasonm', repo_name: 'mangostickyrice', sha: 'aaa111' })
    mock_github_set_commit_status({ oauth_token: token, user_name: 'jasonm', repo_name: 'mangostickyrice', sha: 'bbb222' })
  end

  it 'gets a non-push event, responds with 200 OK' do
    post '/repo_hook', '{}', 'HTTP_X_GITHUB_EVENT' => 'slamalamadingdong'
    expect(response.code).to eq("200")
    expect(response.body).to eq("OK")
  end

  it 'gets a push to a repo without an agreement, responds with 200 OK' do
    payload = { repository: { name: 'no-cla-here', owner: { name: 'wyattearp', email: 'codeslinger@gmail.com' } } }
    post '/repo_hook', { payload: payload.to_json }, 'HTTP_X_GITHUB_EVENT' => 'push'
    expect(response.code).to eq("200")
    expect(response.body).to eq("OK")
  end

  it 'gets a push with 1 commit, where the author has agreed, and marks the commit as success' do
    mock_github_repo_not_collaborator(oauth_token: token, owner: 'jasonm', repo: 'mangostickyrice', user: 'jasonm')
    user = create(:user, email: 'jason@gmail.com', nickname: 'jasonm', oauth_token: token)
    agreement = create(:agreement, user: user, repo_name: 'mangostickyrice')
    create(:signature, user: user, agreement: agreement)

    payload = {
      repository: { name: 'mangostickyrice', owner: { name: 'jasonm', email: 'jason@gmail.com' } },
      commits: [ { id: 'aaa111', author: { name: 'Jason', username: 'jasonm', email: 'jason@gmail.com' } } ]
    }
    post '/repo_hook', { payload: payload.to_json }, 'HTTP_X_GITHUB_EVENT' => 'push'

    status_url = "https://api.github.com/repos/jasonm/mangostickyrice/statuses/aaa111?access_token=#{token}"
    status_params = {
      state: 'success',
      target_url: "#{HOST}/agreements/jasonm/mangostickyrice",
      description: 'All contributors have signed the Contributor License Agreement.',
      context: "clahub"
    }
    expect(a_request(:post, status_url).with(body: status_params.to_json)).to have_been_made
  end

  it 'gets a push with 1 commit, where the author has NOT agreed, and marks the commit as failure' do
    mock_github_repo_not_collaborator(oauth_token: token, owner: 'jasonm', repo: 'mangostickyrice', user: 'jasonm')
    user = create(:user, email: 'jason@gmail.com', nickname: 'jasonm', oauth_token: token)
    agreement = create(:agreement, user: user, repo_name: 'mangostickyrice')

    payload = {
      repository: { name: 'mangostickyrice', owner: { name: 'jasonm', email: 'jason@gmail.com' } },
      commits: [ { id: 'aaa111', author: { name: 'Jason', username: 'jasonm', email: 'jason@gmail.com' } } ]
    }
    post '/repo_hook', { payload: payload.to_json }, 'HTTP_X_GITHUB_EVENT' => 'push'

    status_url = "https://api.github.com/repos/jasonm/mangostickyrice/statuses/aaa111?access_token=#{token}"
    status_params = {
      state: 'failure',
      target_url: "#{HOST}/agreements/jasonm/mangostickyrice",
      description: 'Not all contributors have signed the Contributor License Agreement.',
      context: "clahub"
    }
    expect(a_request(:post, status_url).with(body: status_params.to_json)).to have_been_made
  end

  it 'gets a push, where the author has agreed but the committer has NOT agreed, and marks the commit as failure' do
    mock_github_repo_not_collaborator(oauth_token: token, owner: 'jasonm', repo: 'mangostickyrice', user: 'jasonm')
    mock_github_repo_not_collaborator(oauth_token: token, owner: 'jasonm', repo: 'mangostickyrice', user: 'the-committer')
    author = create(:user, email: 'jasonm@gmail.com', nickname: 'jasonm', oauth_token: token)
    committer = create(:user, email: 'committer@gmail.com', nickname: 'the-committer', oauth_token: token)
    agreement = create(:agreement, user: author, repo_name: 'mangostickyrice')
    create(:signature, user: author, agreement: agreement)

    payload = {
      repository: { name: 'mangostickyrice', owner: { name: 'jasonm', email: 'jasonm@gmail.com' } },
      commits: [ {
        id: 'aaa111',
        author: { name: 'Author', username: 'jasonm', email: 'jasonm@gmail.com' },
        committer: { name: 'Committer', username: 'the-committer', email: 'committer@gmail.com' }
      } ]
    }
    post '/repo_hook', { payload: payload.to_json }, 'HTTP_X_GITHUB_EVENT' => 'push'

    status_url = "https://api.github.com/repos/jasonm/mangostickyrice/statuses/aaa111?access_token=#{token}"
    status_params = {
      state: 'failure',
      target_url: "#{HOST}/agreements/jasonm/mangostickyrice",
      description: 'Not all contributors have signed the Contributor License Agreement.',
      context: "clahub"
    }
    expect(a_request(:post, status_url).with(body: status_params.to_json)).to have_been_made
  end

  it 'gets a push, where the author and committer both agreed, and marks the commit as success' do
    mock_github_repo_not_collaborator(oauth_token: token, owner: 'jasonm', repo: 'mangostickyrice', user: 'jasonm')
    mock_github_repo_not_collaborator(oauth_token: token, owner: 'jasonm', repo: 'mangostickyrice', user: 'the-committer')
    author = create(:user, email: 'jasonm@gmail.com', nickname: 'jasonm', oauth_token: token)
    committer = create(:user, email: 'committer@gmail.com', nickname: 'the-committer', oauth_token: token)
    agreement = create(:agreement, user: author, repo_name: 'mangostickyrice')
    create(:signature, user: author, agreement: agreement)
    create(:signature, user: committer, agreement: agreement)

    payload = {
      repository: { name: 'mangostickyrice', owner: { name: 'jasonm', email: 'jasonm@gmail.com' } },
      commits: [ {
        id: 'aaa111',
        author: { name: 'Author', username: 'jasonm', email: 'jasonm@gmail.com' },
        committer: { name: 'Committer', username: 'the-committer', email: 'committer@gmail.com' }
      } ]
    }
    post '/repo_hook', { payload: payload.to_json }, 'HTTP_X_GITHUB_EVENT' => 'push'

    status_url = "https://api.github.com/repos/jasonm/mangostickyrice/statuses/aaa111?access_token=#{token}"
    status_params = {
      state: 'success',
      target_url: "#{HOST}/agreements/jasonm/mangostickyrice",
      description: 'All contributors have signed the Contributor License Agreement.',
      context: "clahub"
    }
    expect(a_request(:post, status_url).with(body: status_params.to_json)).to have_been_made
  end

  it 'gets a push with many commits, where the single author has agreed, and marks all commits as success' do
    mock_github_repo_not_collaborator(oauth_token: token, owner: 'jasonm', repo: 'mangostickyrice', user: 'jasonm')
    mock_github_repo_not_collaborator(oauth_token: token, owner: 'jasonm', repo: 'mangostickyrice', user: 'the-committer')
    author = create(:user, email: 'jasonm@gmail.com', nickname: 'jasonm', oauth_token: token)
    agreement = create(:agreement, user: author, repo_name: 'mangostickyrice')
    create(:signature, user: author, agreement: agreement)

    payload = {
      repository: { name: 'mangostickyrice', owner: { name: 'jasonm', email: 'jasonm@gmail.com' } },
      commits: [ {
        id: 'aaa111',
        author: { name: 'Author', username: 'jasonm', email: 'jasonm@gmail.com' }
      }, {
        id: 'bbb222',
        author: { name: 'Author', username: 'jasonm', email: 'jasonm@gmail.com' }
      } ]
    }
    post '/repo_hook', { payload: payload.to_json }, 'HTTP_X_GITHUB_EVENT' => 'push'

    status_url = "https://api.github.com/repos/jasonm/mangostickyrice/statuses/aaa111?access_token=#{token}"
    status_params = {
      state: 'success',
      target_url: "#{HOST}/agreements/jasonm/mangostickyrice",
      description: 'All contributors have signed the Contributor License Agreement.',
      context: "clahub"
    }
    expect(a_request(:post, status_url).with(body: status_params.to_json)).to have_been_made

    status_url = "https://api.github.com/repos/jasonm/mangostickyrice/statuses/bbb222?access_token=#{token}"
    status_params = {
      state: 'success',
      target_url: "#{HOST}/agreements/jasonm/mangostickyrice",
      description: 'All contributors have signed the Contributor License Agreement.',
      context: "clahub"
    }
    expect(a_request(:post, status_url).with(body: status_params.to_json)).to have_been_made
  end

  it 'gets a push with many commits, where multiple authors all agreed, and marks the commit as success' do
    mock_github_repo_not_collaborator(oauth_token: token, owner: 'jasonm', repo: 'mangostickyrice', user: 'jasonm')
    mock_github_repo_not_collaborator(oauth_token: token, owner: 'jasonm', repo: 'mangostickyrice', user: 'jugglinmike')
    author1 = create(:user, email: 'jasonm@gmail.com', nickname: 'jasonm', oauth_token: token)
    agreement = create(:agreement, user: author1, repo_name: 'mangostickyrice')
    create(:signature, user: author1, agreement: agreement)
    author2 = create(:user, email: 'jugglinmike@gmail.com', nickname: 'jugglinmike', oauth_token: token)
    create(:signature, user: author2, agreement: agreement)

    payload = {
      repository: { name: 'mangostickyrice', owner: { name: 'jasonm', email: 'jasonm@gmail.com' } },
      commits: [ {
        id: 'aaa111',
        author: { name: 'Author', username: 'jasonm', email: 'jasonm@gmail.com' }
      }, {
        id: 'bbb222',
        author: { name: 'Author', username: 'jugglinmike', email: 'jugglinmike@gmail.com' }
      } ]
    }
    post '/repo_hook', { payload: payload.to_json }, 'HTTP_X_GITHUB_EVENT' => 'push'

    status_url = "https://api.github.com/repos/jasonm/mangostickyrice/statuses/aaa111?access_token=#{token}"
    status_params = {
      state: 'success',
      target_url: "#{HOST}/agreements/jasonm/mangostickyrice",
      description: 'All contributors have signed the Contributor License Agreement.',
      context: "clahub"
    }
    expect(a_request(:post, status_url).with(body: status_params.to_json)).to have_been_made

    status_url = "https://api.github.com/repos/jasonm/mangostickyrice/statuses/bbb222?access_token=#{token}"
    status_params = {
      state: 'success',
      target_url: "#{HOST}/agreements/jasonm/mangostickyrice",
      description: 'All contributors have signed the Contributor License Agreement.',
      context: "clahub"
    }
    expect(a_request(:post, status_url).with(body: status_params.to_json)).to have_been_made
  end

  it 'gets a push with many commits, where some authors agreed and others did not, and marks each commit correctly' do
    mock_github_repo_not_collaborator(oauth_token: token, owner: 'jasonm', repo: 'mangostickyrice', user: 'jasonm')
    mock_github_repo_not_collaborator(oauth_token: token, owner: 'jasonm', repo: 'mangostickyrice', user: 'the-committer')
    author1 = create(:user, email: 'jasonm@gmail.com', nickname: 'jasonm', oauth_token: token)
    agreement = create(:agreement, user: author1, repo_name: 'mangostickyrice')
    create(:signature, user: author1, agreement: agreement)

    payload = {
      repository: { name: 'mangostickyrice', owner: { name: 'jasonm', email: 'jasonm@gmail.com' } },
      commits: [ {
        id: 'aaa111',
        author: { name: 'Author', username: 'jasonm', email: 'jasonm@gmail.com' }
      }, {
        id: 'bbb222',
        author: { name: 'Author', username: 'jugglinmike', email: 'jugglinmike@gmail.com' }
      } ]
    }
    post '/repo_hook', { payload: payload.to_json }, 'HTTP_X_GITHUB_EVENT' => 'push'

    status_url = "https://api.github.com/repos/jasonm/mangostickyrice/statuses/aaa111?access_token=#{token}"
    status_params = {
      state: 'success',
      target_url: "#{HOST}/agreements/jasonm/mangostickyrice",
      description: 'All contributors have signed the Contributor License Agreement.',
      context: "clahub"
    }
    expect(a_request(:post, status_url).with(body: status_params.to_json)).to have_been_made

    status_url = "https://api.github.com/repos/jasonm/mangostickyrice/statuses/bbb222?access_token=#{token}"
    status_params = {
      state: 'failure',
      target_url: "#{HOST}/agreements/jasonm/mangostickyrice",
      description: 'Not all contributors have signed the Contributor License Agreement.',
      context: "clahub"
    }
    expect(a_request(:post, status_url).with(body: status_params.to_json)).to have_been_made
  end

  it 'updates applicable "failure" commit statuses to "success" when a user agrees to a new agreement'

  it 'gets a push, where the author is a collaborator and marks the commit as success' do
    author = create(:user, email: 'ryan@strongloop.com', nickname: 'rmg', oauth_token: token)
    agreement = create(:agreement, user: author, repo_name: 'mangostickyrice')
    mock_github_repo_collaborator(oauth_token: token, owner: 'rmg', repo: 'mangostickyrice', user: 'rmg')
    mock_github_set_commit_status(oauth_token: token, user_name: 'rmg', repo_name: 'mangostickyrice', sha: 'aaa111')
    expect(Signature.all).to be_empty

    payload = {
      repository: { name: 'mangostickyrice', owner: { name: 'rmg', email: 'ryan@strongloop.com' } },
      commits: [ {
        id: 'aaa111',
        author: { name: 'Author', username: 'rmg', email: 'ryan@strongloop.com' },
        committer: { name: 'Committer', username: 'rmg', email: 'ryan@strongloop.com' }
      } ]
    }
    post '/repo_hook', { payload: payload.to_json }, 'HTTP_X_GITHUB_EVENT' => 'push'

    status_url = "https://api.github.com/repos/rmg/mangostickyrice/statuses/aaa111?access_token=#{token}"
    status_params = {
      state: 'success',
      target_url: "#{HOST}/agreements/rmg/mangostickyrice",
      description: 'All contributors have signed the Contributor License Agreement.',
      context: "clahub"
    }
    expect(a_request(:post, status_url).with(body: status_params.to_json)).to have_been_made
  end
end
