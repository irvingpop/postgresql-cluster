include_recipe "postgresql-cluster::destroy_#{node['postgresql-cluster']['provisioning']['driver']}"
