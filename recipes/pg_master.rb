
# repmgr create repmgr db
execute "create_db_#{node['postgresql-cluster']['repmgr']['db_name']}" do
  command "createdb -U postgres #{node['postgresql-cluster']['repmgr']['db_name']} -O #{node['postgresql-cluster']['repmgr']['db_user']}"
  action :run
  user 'postgres'
  not_if "psql postgres -c 'SELECT datname FROM pg_database' |grep #{node['postgresql-cluster']['repmgr']['db_name']}"
end

# repmgr register
execute 'repmgr_master_register' do
  command "#{node['postgresql']['bin_dir']}/repmgr -f #{node['postgresql-cluster']['repmgr']['conf_file']} master register"
  action :run
  # reverse psychology
  not_if "#{node['postgresql']['bin_dir']}/repmgr -f #{node['postgresql-cluster']['repmgr']['conf_file']} cluster show"
end
