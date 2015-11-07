#
# Cookbook Name:: postgresql-cluster
# Recipe:: default
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

include_recipe 'chef-provisioning-vagrant-helper::default'

machine_batch 'precreate' do
  action [:converge]

  node['postgresql-cluster']['cluster_nodes'].each do |vmname|
    machine vmname do
      recipe 'postgresql-cluster::default'
      attribute 'postgresql-cluster', { use_interface: 'enp0s8' }
      machine_options vagrant_options(vmname)
      # see chef-provisioning-vagrant-helper/libraries/vagrant_config.rb
    end
  end
end
