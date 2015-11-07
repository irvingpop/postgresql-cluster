#
# Cookbook Name:: postgresql-cluster
# Spec:: default
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

require 'spec_helper'

describe 'postgresql-cluster::default' do
  context 'When all attributes are default, on an unspecified platform' do
    let(:chef_run) do
      runner = ChefSpec::ServerRunner.new do |node|
        node.automatic['memory']['total'] = 666
      end
      runner.converge(described_recipe)
    end

    before do
       stub_command("test -f /var/lib/pgsql/9.4-bdr/data/PG_VERSION").and_return(false)
       # why doesn't this work
       stub_command("sudo -u postgres /usr/pgsql-9.4/bin/psql postgres -c 'SELECT datname FROM pg_database' |grep opscode_chef").and_return(false)
    end

    it 'converges successfully' do
      chef_run # This should not raise an error
    end
  end
end
