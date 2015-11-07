task :default => [:up]

desc 'Bring up the Postgres cluster (default)'
task :up => :setup do
  sh('chef-client -z -o postgresql-cluster::provision')
end

desc 'Destroy the Postgres cluster'
task :destroy do
  sh('chef-client -z -o postgresql-cluster::destroy')
end
task :cleanup => :destroy

desc 'Destroy and rebuild each node of the cluster individually'
task :rolling_rebuild => :setup do
  sh('chef-client -z -o postgresql-cluster::rolling_rebuild')
end

desc 'Chef setup tasks'
task :setup do
  unless Dir.exist?('vendor')
    sh('berks install --quiet')
    Dir.mkdir('vendor')
    sh('berks vendor vendor/ --quiet')
  else
    sh('berks update --quiet')
    sh('rm -rf vendor/*')
    sh('berks vendor vendor/ --quiet')
  end
end
