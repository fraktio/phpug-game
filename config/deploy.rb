
require 'capistrano/ext/multistage'

set :stage_dir, 'config/deploy'
set :stages, %w[production]
set :default_stage, 'production'

set :application, "PHPUG-Game"
set :node_file, "server.js"
set :repository, "git@github.com:fraktio/phpug-game.git"

set :scm, :git
set :deploy_via, :remote_cache
role(:app) { host }
set :use_sudo, true
default_run_options[:pty] = true

namespace :deploy do
  task :start, :roles => :app, :except => { :no_release => true } do
    run "#{sudo} start #{application}_#{node_env}"
  end

  task :stop, :roles => :app, :except => { :no_release => true } do
    run "#{sudo} stop #{application}_#{node_env}"
  end

  task :restart, :roles => :app, :except => { :no_release => true } do
    run "#{sudo} restart #{application}_#{node_env} || sudo start #{application}_#{node_env}"
  end

  task :create_deploy_to, :roles => :app do
    run "mkdir -p #{deploy_to}"
  end

  task :write_upstart_script, :roles => :app do
    upstart_script = <<-UPSTART
  description "#{application}"

  start on startup
  stop on shutdown

  script
      export HOME="/home/#{admin_runner}"
      export NODE_ENV="#{node_env}"

      cd #{current_path}
      exec sudo -u #{admin_runner} sh -c "NODE_ENV=#{node_env} #{node_path}/node #{current_path}/#{node_file} #{application_port} >> #{shared_path}/log/#{node_env}.log 2>&1"
  end script
  respawn
UPSTART
  put upstart_script, "/tmp/#{application}_upstart.conf"
    run "#{sudo} mv /tmp/#{application}_upstart.conf /etc/init/#{application}_#{node_env}.conf"
  end

  task :npm_update, :roles => :app do
    run "cd #{release_path}; #{node_path}/node #{node_path}/npm install"
  end

end

before 'deploy:setup', 'deploy:create_deploy_to'
after 'deploy:setup', 'deploy:write_upstart_script'
after "deploy:finalize_update", "deploy:npm_update"

