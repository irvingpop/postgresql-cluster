#
# Cookbook Name:: postgresql-cluster
# Recipe:: default
#
# Copyright (c) 2015 Irving Popovetsky, All Rights Reserved.

def get_master_node
  results = search(:node, "tags:pg_master",
    filter_result: {
      'name' => [ 'name' ],
      'fqdn' => [ 'fqdn' ],
    }
  )

  results.first['name']
end
master_node = get_master_node

# first, populate /etc/hosts from search results
def extract_cluster_ip(node_results)
  use_interface = node['postgresql-cluster']['use_interface']
  node_results['network_interfaces'][use_interface]['addresses']
    .select { |k,v| v['family'] == 'inet' }.keys
end

found_nodes = search(:node, "name:postgresql-*",
  filter_result: {
    'name' => [ 'name' ],
    'fqdn' => [ 'fqdn' ],
    'network_interfaces' => [ 'network', 'interfaces' ]
  }
).reject { |nodedata| nodedata['network_interfaces'].nil? } #not if no interface data
  .reject { |nodedata| nodedata['name'] == node.name } # not if it's me

found_nodes.each do |nodedata|
  hostsfile_entry extract_cluster_ip(nodedata) do
    hostname nodedata['name']
    aliases [ nodedata['fqdn'], nodedata['name'].split('.').first ]
    unique true
    comment 'Chef postgresql-cluster cookbook'
  end
end


## Base PostgreSQL setup
include_recipe 'postgresql::server'

# goofy stuff to make Ubuntu and Redhat packages behave the same way
link "/etc/postgresql/#{node['postgresql']['version']}/main/postgresql.conf" do
  to "#{node['postgresql']['dir']}/postgresql.conf"
  owner 'postgres'
  group 'postgres'
  only_if { node['platform_family'] == 'debian' }
  notifies :restart, 'service[postgresql]', :immediately
end

include_recipe 'postgresql-cluster::ssh_trust'

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
  variables node_id: (node['postgresql-cluster']['cluster_nodes'].index(node.name) + 1),
    master_node: master_node
end


# begin cheapo master/slave setup.  what this should look like is:
# if a node is tagged `pg_master`:
#   check to see if repmgr is setup (repmgr db exists)
#     if not, set it up
#     if so, verify the operational state from repmgr's perspective (cluster show?)
#        verify if this machine is still really the master.
#          if not(another machine has become the master), remote the pg_master tag and set a pg_slave tag.
#             see if this node has been set as a slave, if not set it up as one
#          if no masters, bomb
#
#  if a node is tagged as a slave
#    check to see if repmgr is setup on the master
#      if not, bomb or go into a sleep loop?
#         if timeout?   (should we expect an external actor such as pgpool or repmgrd to handle failover for us?)

if node.tags.include?('pg_master')

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
else
  # the process for initting a standby is:  stop service, wipe data dir, clone, start service, reregister standby
  # this is guarded by a guard file, would love a more sane approach
  guardfile = ::File.join(node['postgresql']['home'], 'standby_initted')

  # DANGER ZONE
  service node['postgresql']['server']['service_name'] do
    supports :status => true
    action :stop
    not_if "test -f #{guardfile}"
  end

  directory node['postgresql']['dir'] do
    recursive true
    action :delete
    not_if "test -f #{guardfile}"
  end

  # repmgr clone
  execute 'repmgr_standby_clone' do
    command "#{node['postgresql']['bin_dir']}/repmgr -f #{node['postgresql-cluster']['repmgr']['conf_file']} -d #{node['postgresql-cluster']['repmgr']['db_name']} -U #{node['postgresql-cluster']['repmgr']['db_user']} --verbose standby clone #{master_node}"
    environment ({ 'PGPASSWORD' => node['postgresql-cluster']['repmgr']['db_password'] })
    user 'postgres'
    action :run
    not_if "test -f #{guardfile}"
  end

  # start service
  service node['postgresql']['server']['service_name'] do
    supports :status => true
    action [ :enable, :start ]
    not_if "test -f #{guardfile}"
  end

  # repmgr register
  execute 'repmgr_standby_register' do
    command "#{node['postgresql']['bin_dir']}/repmgr -f #{node['postgresql-cluster']['repmgr']['conf_file']} --verbose standby register"
    user 'postgres'
    action :run
    not_if "test -f #{guardfile}"
  end

  # TODO: insert better guard here
  file guardfile do
    owner 'root'
    group 'root'
    mode 00755
    action :create
    content "Created by the postgresql-cluster cookbook.\nREMOVING THIS FILE WILL WIPE THE POSTGRES DATA\n"
  end
end
