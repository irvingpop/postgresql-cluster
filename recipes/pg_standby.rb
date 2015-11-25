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
