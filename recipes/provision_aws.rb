#
# Cookbook Name:: postgresql-cluster
# Recipe:: default
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

include_recipe 'chef-provisioning-aws-helper::default'

# dummy master/slave assignment TODO: fixme
pg_master = node['postgresql-cluster']['cluster_nodes'].first
pg_slaves = node['postgresql-cluster']['cluster_nodes'].reject { |i| i == pg_master }

all_cluster_nodes = node['postgresql-cluster']['cluster_nodes'] + node['postgresql-cluster']['pgpool_nodes']

# Pre-create the machines in parallel for faster provisioning
machine_batch 'postgres_precreate' do
  action [:converge]

  all_cluster_nodes.each do |vmname|
    next if aws_instance_created?(vmname)

    machine vmname do
      machine_options aws_options(vmname)
      recipe 'postgresql-cluster::aws_instance_setup'

      if vmname == pg_master
        tag 'pg_master'
      else
        tag 'pg_slave'
      end

    end
  end

end

# do Postgres setup sequentially
node['postgresql-cluster']['cluster_nodes'].each do |vmname|
  machine vmname do
    recipe 'postgresql-cluster::default'
  end
end


# do Pgpool setup sequentially
node['postgresql-cluster']['pgpool_nodes'].each do |vmname|
  machine vmname do
    recipe 'postgresql-cluster::pgpool'
  end
end
