#
# Cookbook Name:: postgresql-cluster
# Recipe:: default
#
# Copyright (c) 2015 Irving Popovetsky, All Rights Reserved.

include_recipe 'postgresql-cluster::hostsfile'
include_recipe 'postgresql::server'
include_recipe 'postgresql-cluster::ssh_trust'
include_recipe 'postgresql-cluster::pg_replication'

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
  include_recipe 'postgresql-cluster::pg_master'
else
  include_recipe 'postgresql-cluster::pg_standby'
end
