# goofy stuff to make Ubuntu and Redhat packages behave the same way
link "/etc/postgresql/#{node['postgresql']['version']}/main/postgresql.conf" do
  to "#{node['postgresql']['dir']}/postgresql.conf"
  owner 'postgres'
  group 'postgres'
  only_if { node['platform_family'] == 'debian' }
  notifies :restart, 'service[postgresql]', :immediately
end

# Pgpool specific setup

# TODO: fixme postgres extension registration for pgpool
%w(pgpool_regclass pgpool_recovery).each do |extension|
  execute "create_extension_#{extension}" do
    command "psql template1 -c 'CREATE EXTENSION IF NOT EXISTS #{extension}'"
    user 'postgres'
    not_if "psql template1 -c 'SELECT extname FROM pg_extension' |grep #{extension}"
  end
end

# pgpool_recovery runs on the master database node - it is triggered by a database function, called by pgpool
# it calls the script with the same name, located in the $PGDATA directory
# ex: SELECT pgpool_recovery('pgpool_recovery', 'standbynode', '/var/lib/pgsql/9.4/data');
template "#{node['postgresql']['dir']}/pgpool_recovery" do
  source 'pgpool_recovery.erb'
  owner 'postgres'
  mode 00755
end

#  pgpool_remote_start runs on a database node - it is triggered by a database function
#  ex: SELECT pgpool_remote_start('postgresql-1.example.com', '/var/lib/pgsql/9.4/data')
template "#{node['postgresql']['dir']}/pgpool_remote_start" do
  source 'pgpool_remote_start.erb'
  owner 'postgres'
  mode 00755
end


# Repmgr setup

# TODO: fixme replication user's password generation
execute 'create replication user' do
  command %Q(psql postgres -c "CREATE ROLE #{node['postgresql-cluster']['repmgr']['db_user']} WITH REPLICATION PASSWORD '#{node['postgresql-cluster']['repmgr']['db_password']}' SUPERUSER LOGIN")
  user 'postgres'
  action :run
  not_if "psql postgres -c 'SELECT usename FROM pg_user' |grep #{node['postgresql-cluster']['repmgr']['db_user']}"
end

directory node['postgresql-cluster']['repmgr']['etc_dir'] do
  owner 'postgres'
  mode 00755
  recursive true
  action :create
end

template node['postgresql-cluster']['repmgr']['conf_file'] do
  source 'repmgr.conf.erb'
  owner 'root'
  group 'root'
  mode 00744
  # cheapo way to generate a node id based on my position in the cluster
  variables node_id: (node['postgresql-cluster']['cluster_nodes'].index(node['name']) + 1),
    master_node: master_node
end
