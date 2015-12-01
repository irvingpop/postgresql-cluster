#
# Cookbook Name:: postgresql-cluster
# Spec:: default
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

require 'spec_helper'

describe 'postgresql-cluster::default' do
  context 'When all attributes are default, on an unspecified platform' do
    let(:chef_run) do
      runner = ChefSpec::SoloRunner.new do |node|
        node.automatic['memory']['total'] = 666
        node.set['postgresql']['version'] = '9.4'
        node.set['postgresql']['password']['postgres'] = 'randomnotrandom'
        node.set['postgresql']['home'] = '/var/lib/postgresql'
        node.set['postgresql-cluster']['cluster_nodes'] = 1.upto(2).map { |i| "postgresql-#{i}.example.com" }
        node.automatic['name'] = 'postgresql-1.example.com'
      end
      runner.converge(described_recipe)
    end

    before do
      stub_command("ls /etc/postgresql/9.4/main/recovery.conf").and_return(true)
      stub_command("psql template1 -c 'SELECT extname FROM pg_extension' |grep pgpool_regclass").and_return(false)
      stub_command("psql template1 -c 'SELECT extname FROM pg_extension' |grep pgpool_recovery").and_return(false)
      stub_command("psql postgres -c 'SELECT usename FROM pg_user' |grep replication").and_return(false)
      stub_command("test -f /var/lib/postgresql/standby_initted").and_return(false)
    end

    it 'converges successfully' do
      stub_data_bag_item(:sshkeys, 'postgres_ssh').and_return({ id: 'postgres_ssh',
        public_key: "ssh-rsa whoosa user@computer\n",
        private_key: "-----BEGIN RSA PRIVATE KEY-----\nstuff\n-----END RSA PRIVATE KEY-----\n"
        })

      stub_search("node", "name:postgresql-*").and_return(
        1.upto(2).map do |i|
          {
            name: "postgresql-#{i}.example.com",
            fqdn: "postgresql-#{i}.example.com",
            network_interfaces: { eth0: { addresses: { "33.33.33.#{i}" => { family: 'inet' } } } }
          }
        end
      )

      stub_search("node", "tags:pg_master").and_return(
        [{
          name: "postgresql-1.example.com",
          fqdn: "postgresql-1.example.com"
        }]
      )

      chef_run # This should not raise an error
    end
  end
end
