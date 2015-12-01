#
# Cookbook Name:: postgresql-cluster
# Spec:: pgpool
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

require 'spec_helper'

describe 'postgresql-cluster::pgpool' do
  context 'When all attributes are default, on an unspecified platform' do
    let(:chef_run) do
      runner = ChefSpec::SoloRunner.new do |node|
        node.automatic['memory']['total'] = 666
        node.set['postgresql']['version'] = '9.4'
        node.set['postgresql']['home'] = '/var/lib/postgresql'
      end
      runner.converge(described_recipe)
    end

    before do
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
      
      chef_run # This should not raise an error
    end
  end
end
