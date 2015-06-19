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
    @github ||= Github.new(oauth_token: user.oauth_token, auto_pagination: true)
  end

  def repos
    [user_repos, org_repos].flatten
  end

  def collaborator?(user_name, repo_name, user)
    @github.repos.collaborators.collaborator?(user_name, repo_name, user.nickname) rescue false
  end

  def create_hook(user_name, repo_name, hook_inputs)
    begin
      @github.repos.hooks.create(user_name, repo_name, hook_inputs)
    rescue error_response(/422 Hook already exists on this repository/)
      @github.repos.hooks.list(user_name, repo_name).find { |h|
        h.name == hook_inputs['name'] and h.config == hook_inputs['config']
      }
    end
  end

  def edit_hook(user_name, repo_name, id, hook_inputs)
    @github.repos.hooks.edit(user_name, repo_name, id, hook_inputs)
  end

  def get_hook(user_name, repo_name, id)
    @github.repos.hooks.fetch(user_name, repo_name, id) rescue nil
  end

  def delete_hook(user_name, repo_name, hook_id)
    @github.repos.hooks.delete(user_name, repo_name, hook_id)
  end

  def set_status(user_name, repo_name, sha, params)
    @github.repos.statuses.create(user_name, repo_name, sha, params)
  end

  def get_pulls(user_name, repo_name)
    @github.pull_requests.list(user_name, repo_name)
  end

  def get_pull_commits(user_name, repo_name, pull_id)
    @github.pull_requests.commits(user_name, repo_name, pull_id)
  end
  private

  def user_repos
    @github.repos.list(per_page: REPOS_PER_PAGE).sort_by(&:name)
  end

  def org_repos
    repos = []
    @github.orgs.list.each do |org|
      @github.repos.list(org: org.login, per_page: REPOS_PER_PAGE).each do |repo|
        if repo.permissions.admin
          repos.push(repo)
        end
      end
    end
    repos
  end
end
