I_AGREE = Field.find_by_label('Type "I AGREE"')
AGREEMENT_TEMPLATE = {
  text: IO.read('strongloop-cla.md'),
  agreement_fields_attributes: [
    { field: I_AGREE, enabled: true }
  ]
}

puts "GitHub username:"
admin_username = STDIN.gets.chomp

owner = User.find_by_nickname(admin_username)

if owner && owner.oauth_token
  puts "Found owner: #{owner.inspect}"
  gh = Github.new(oauth_token: owner.oauth_token, auto_pagination: true)
else
  puts "GitHub password:"
  admin_password = STDIN.gets.chomp

  gh_boot = Github.new(basic_auth: "#{admin_username}:#{admin_password}")
  auth = gh_boot.oauth.app.create(ENV['GITHUB_KEY'],
                                  client_secret: ENV['GITHUB_SECRET'],
                                  scope: 'public_repo')
  gh = Github.new(oauth_token: auth.token, auto_pagination: true)
  gh_user = gh.users.get
  owner = User.find_or_create_for_github_oauth(uid: gh_user.id,
                                              name: gh_user.name,
                                              nickname: gh_user.login,
                                              oauth_token: auth.token,
                                              email: gh_user.email)
  puts "Created owner: #{owner.inspect}"
end

repos = gh.repos
          .list(org: 'strongloop')
          .reject(&:private?)
          .reject(&:fork?)
          .reject { |r|
            if r.name =~ /express/ or r.name == 'strong-agent'
              puts "Excluded: #{r.full_name}"
              true
            end
          }
          .sort_by(&:name)
repos.map { |repo|
  owner.agreements.where(user_name: repo.owner.login,
                         repo_name: repo.name)
                  .first_or_create(AGREEMENT_TEMPLATE)
}.each do |agreement|
  puts "#{agreement.user_name}/#{agreement.repo_name}"
end.tap { |all| p "Total: #{all.count}" }
