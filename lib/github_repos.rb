class GithubRepos
  REPOS_PER_PAGE = 100 # the max

  def error_response(pattern)
    m = Module.new
    (class << m; self; end).instance_eval do
      define_method(:===) do |e|
        pattern === e.message
      end
    end
    m
  end

  def initialize(user)
    @github ||= Octokit::Client.new(access_token: user.oauth_token, auto_pagination: true)
  end

  def repos
    [user_repos, org_repos].flatten
  end

  def collaborator?(user_name, repo_name, user)
    @github.collaborator?("#{user_name}/#{repo_name}", user.nickname) rescue false
  end

  def create_hook(user_name, repo_name, hook_inputs)
    begin
      @github.create_hook("#{user_name}/#{repo_name}", hook_inputs["name"], hook_inputs["config"])
    rescue error_response(/422 Hook already exists on this repository/)
      @github.hooks("#{user_name}/#{repo_name}").find { |h|
        h.name == hook_inputs['name'] and h.config == hook_inputs['config']
      }
    end
  end

  def edit_hook(user_name, repo_name, id, hook_inputs)
    @github.edit_hook("#{user_name}/#{repo_name}", id, name, hook_inputs["name"], hook_inputs["config"])
  end

  def delete_hook(user_name, repo_name, hook_id)
    @github.remove_hook("#{user_name}/#{repo_name}", hook_id)
  end

  def set_status(user_name, repo_name, sha, state, params)
    @github.create_status("#{user_name}/#{repo_name}", sha, state, params)
  end

  def get_pulls(user_name, repo_name)
    @github.pull_requests("#{user_name}/#{repo_name}")
  end

  def get_pull_commits(user_name, repo_name, pull_id)
    @github.pull_request_commits("#{user_name}/#{repo_name}", pull_id)
  end
  private

  def user_repos
    @github.repositories #.sort_by(&:name)
  end

  def org_repos
    repos = []
    @github.orgs.each do |org|
      @github.repositories(org.login).each do |repo|
        if repo.permissions.admin
          repos.push(repo)
        end
      end
    end
    repos
  end
end
