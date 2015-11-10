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

# TODO: fixme postgres extension registration for pgpool
%w(pgpool_regclass pgpool_recovery).each do |extension|
  execute "create_extension_#{extension}" do
    command "psql template1 -c 'CREATE EXTENSION IF NOT EXISTS #{extension}'"
    user 'postgres'
    not_if "psql template1 -c 'SELECT extname FROM pg_extension' |grep #{extension}"
  end
end

# TODO: fixme replication user's password generation
execute 'create replication user' do
  command %Q(psql postgres -c "CREATE ROLE #{node['postgresql-cluster']['repmgr']['db_user']} WITH REPLICATION PASSWORD '#{node['postgresql-cluster']['repmgr']['db_password']}' SUPERUSER LOGIN")
  user 'postgres'
  action :run
  not_if "psql postgres -c 'SELECT usename FROM pg_user' |grep #{node['postgresql-cluster']['repmgr']['db_user']}"
end

template "/etc/repmgr/9.4/repmgr.conf" do
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
    command "/usr/pgsql-9.4/bin/repmgr -f /etc/repmgr/9.4/repmgr.conf master register"
    action :run
    # reverse psychology
    not_if "/usr/pgsql-9.4/bin/repmgr -f /etc/repmgr/9.4/repmgr.conf cluster show"
  end

  # create databases
  node['postgresql-cluster']['dbnames'].each do |dbname|
    execute "create_db_#{dbname}" do
      command "createdb -U postgres #{dbname}"
      action :run
      user 'postgres'
      not_if "psql postgres -c 'SELECT datname FROM pg_database' |grep #{dbname}"
    end
  end
else
  # the process for initting a standby is:  stop service, wipe data dir, clone, start service, reregister standby
  # this is guarded by a guard file, would love a more sane approach
  guardfile = "/var/lib/pgsql/standby_initted"

  # DANGER ZONE
  service 'postgresql-9.4' do
    supports :status => true
    action :stop
    not_if "test -f #{guardfile}"
  end

  directory '/var/lib/pgsql/9.4/data' do
    recursive true
    action :delete
    not_if "test -f #{guardfile}"
  end

  # repmgr clone
  execute 'repmgr_standby_clone' do
    command "/usr/pgsql-9.4/bin/repmgr -f /etc/repmgr/9.4/repmgr.conf -d #{node['postgresql-cluster']['repmgr']['db_name']} -U #{node['postgresql-cluster']['repmgr']['db_user']} --verbose standby clone #{master_node}"
    environment ({ 'PGPASSWORD' => node['postgresql-cluster']['repmgr']['db_password'] })
    user 'postgres'
    action :run
    not_if "test -f #{guardfile}"
  end

  # start service
  service 'postgresql-9.4' do
    supports :status => true
    action [ :enable, :start ]
    not_if "test -f #{guardfile}"
  end

  # repmgr register
  execute 'repmgr_standby_register' do
    command '/usr/pgsql-9.4/bin/repmgr -f /etc/repmgr/9.4/repmgr.conf --verbose standby register'
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
