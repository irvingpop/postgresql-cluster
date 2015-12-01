default['postgresql-cluster']['domain_name'] = 'example.com'

cluster_nodes_count = 2
default['postgresql-cluster']['cluster_nodes'] = 1.upto(cluster_nodes_count).map { |i| "postgresql-#{i}.#{node['postgresql-cluster']['domain_name']}" }

pgpool_nodes_count = 1
default['postgresql-cluster']['pgpool_nodes'] = 1.upto(pgpool_nodes_count).map { |i| "pgpool-#{i}.#{node['postgresql-cluster']['domain_name']}" }

# Provisiong driver settings
default['postgresql-cluster']['provisioning']['driver'] = 'aws'

if node['postgresql-cluster']['provisioning']['driver'] == 'vagrant'
  default['postgresql-cluster']['use_interface'] = 'eth1'
else
  default['postgresql-cluster']['use_interface'] = 'eth0'
end

# SSH key setup for postgres user (for failover scripts)
default['postgresql-cluster']['sshkey_databag'] = 'sshkeys'
default['postgresql-cluster']['postgres_keypair_name'] = 'postgres_ssh'

# Vagrant settings
default['chef-provisioning-vagrant']['vbox']['box'] = 'box-cutter/centos71'
default['chef-provisioning-vagrant']['vbox']['ram'] = 512
default['chef-provisioning-vagrant']['vbox']['cpus'] = 1
default['chef-provisioning-vagrant']['vbox']['private_networks']['default'] = 'dhcp'

# AWS settings
default['chef-provisioning-aws']['region'] = 'us-west-2'
default['chef-provisioning-aws']['instance_type'] = 'c3.xlarge'
default['chef-provisioning-aws']['ebs_optimized'] = true
default['chef-provisioning-aws']['subnet_id'] = 'subnet-b2bb82f4'
default['chef-provisioning-aws']['keypair_name'] = "#{ENV['USER']}@postgresql-cluster"
default['chef-provisioning-aws']['aws_tags'] = { 'X-Project' => 'chef-ha' }

# AWS OS chooser
default['chef-provisioning-aws']['ami_os'] = 'ubuntu'
case node['chef-provisioning-aws']['ami_os']
when 'amazon' # note: haven't tested amazon linux
  default['chef-provisioning-aws']['ssh_username'] = 'ec2-user'
  default['chef-provisioning-aws']['image_id'] = 'ami-f0091d91' # Amazon Linux AMI 2015.09.1
when 'rhel'
  default['chef-provisioning-aws']['ssh_username'] = 'ec2-user'
  default['chef-provisioning-aws']['image_id'] = 'ami-c15a52f1' # RHEL-7.1_HVM-20150803-x86_64
when 'ubuntu'
  default['chef-provisioning-aws']['ssh_username'] = 'ubuntu'
  default['chef-provisioning-aws']['image_id'] = 'ami-d24c5cb3' # Trusty hvm-ssd release 20151117
end

# Postgres platform-specific settings for using PGDG (postgresql.org repos/packages)
default['postgresql']['version'] = '9.4'
case node['platform_family']
when 'rhel'
  default['postgresql']['enable_pgdg_yum'] = true
  default['postgresql']['client']['packages'] = %w(postgresql94-devel)
  default['postgresql']['contrib']['packages'] = %w(postgresql94-contrib)
  default['postgresql']['server']['packages'] = %w(postgresql94-server pgpool-II-94-extensions repmgr94)
  default['postgresql']['server']['service_name'] = "postgresql-#{node['postgresql']['version']}"
  default['postgresql']['home'] = '/var/lib/pgsql'
  default['postgresql']['dir'] = ::File.join(node['postgresql']['home'], node['postgresql']['version'], 'data')
  default['postgresql']['bin_dir'] = "/usr/pgsql-#{node['postgresql']['version']}/bin"
  default['postgresql']['config']['log_directory'] = '/var/log/postgresql'
when 'debian'
  default['postgresql']['enable_pgdg_apt'] = true
  default['postgresql']['client']['packages'] = %w(postgresql-client-9.4)
  default['postgresql']['contrib']['packages'] = %w(postgresql-contrib-9.4)
  default['postgresql']['server']['packages'] = %w(postgresql-9.4 postgresql-9.4-pgpool2 postgresql-9.4-repmgr)
  default['postgresql']['server']['service_name'] = 'postgresql'
  default['postgresql']['home'] = '/var/lib/postgresql'
  default['postgresql']['dir'] = ::File.join(node['postgresql']['home'], node['postgresql']['version'], 'main')
  default['postgresql']['bin_dir'] = ::File.join('/usr/lib/postgresql', node['postgresql']['version'], 'bin')
  default['postgresql']['config']['hba_file'] = ::File.join(node['postgresql']['dir'], 'pg_hba.conf')
  default['postgresql']['config']['ident_file'] = "/etc/postgresql/#{node['postgresql']['version']}/main/pg_ident.conf"
  default['postgresql']['config']['external_pid_file'] = "/var/run/postgresql/#{node['postgresql']['version']}-main.pid"
  default['postgresql']['config']['log_directory'] = '/var/log/postgresql'
end

# Repmgr settings
default['postgresql-cluster']['cluster_name'] = 'example'
default['postgresql-cluster']['repmgr']['db_name'] = 'repmgr_db'
default['postgresql-cluster']['repmgr']['db_user'] = 'replication'
default['postgresql-cluster']['repmgr']['db_password'] = 'replication'
default['postgresql-cluster']['repmgr']['etc_dir'] = ::File.join('/etc/repmgr', node['postgresql']['version'])
default['postgresql-cluster']['repmgr']['conf_file'] = ::File.join(node['postgresql-cluster']['repmgr']['etc_dir'], 'repmgr.conf')

# pgpool from pgdg
default['postgresql']['version'] = '9.4'
case node['platform_family']
when 'rhel'
  default['pgpool']['config']['package_name'] = 'pgpool-II-94'
  default['pgpool']['service'] = 'pgpool-II-94'
  default['pgpool']['config']['dir'] = '/etc/pgpool-II-94'
when 'debian'
  default['pgpool']['config']['package_name'] = 'pgpool2'
  default['pgpool']['service'] = 'pgpool2'
  default['pgpool']['config']['dir'] = '/etc/pgpool2'
  default['pgpool']['pgconf']['pid_file_name'] = '/var/run/postgresql/pgpool.pid'
  default['pgpool']['pgconf']['socket_dir'] = '/var/run/postgresql'
  default['pgpool']['pgconf']['pcp_socket_dir'] = '/var/run/postgresql'
else # the dangers of mixing provisioning and regular cookbooks into one, these need to evaluate from your laptop/provisioner node
  default['pgpool']['config']['package_name'] = 'pgpool2'
  default['pgpool']['service'] = 'pgpool2'
  default['pgpool']['config']['dir'] = '/etc/pgpool2'
end
default['pgpool']['pgconf']['listen_addresses'] = '*'
default['pgpool']['pgconf']['num_init_children'] = 256
default['pgpool']['pgconf']['port'] = 5432  # using the default postgres port here because we expect pgpool to run on a separate box
default['pgpool']['pgconf']['master_slave_mode'] = true
default['pgpool']['pgconf']['health_check_period'] = 10
default['pgpool']['pgconf']['health_check_timeout'] = 20
default['pgpool']['pgconf']['health_check_max_retries'] = 3
default['pgpool']['pgconf']['health_check_user'] = node['postgresql-cluster']['repmgr']['db_user']
default['pgpool']['pgconf']['health_check_password'] = node['postgresql-cluster']['repmgr']['db_password']
default['pgpool']['pgconf']['sr_check_user'] = node['postgresql-cluster']['repmgr']['db_user']
default['pgpool']['pgconf']['sr_check_password'] = node['postgresql-cluster']['repmgr']['db_password']
default['pgpool']['pgconf']['failover_command'] = "#{node['pgpool']['config']['dir']}/failover.sh %h %H"
default['pgpool']['pgconf']['failback_command'] = "#{node['pgpool']['config']['dir']}/failover.sh %h %H"
default['pgpool']['pgconf']['follow_master_command'] = "#{node['pgpool']['config']['dir']}/follow_master.sh %D %h %H"
default['pgpool']['pgconf']['recovery_first_stage_command'] = 'pgpool_recovery'
default['pgpool']['pgconf']['recovery_user'] = node['postgresql-cluster']['repmgr']['db_user']
default['pgpool']['pgconf']['recovery_password'] = node['postgresql-cluster']['repmgr']['db_password']
default['pgpool']['pgconf']['recovery_timeout'] = 300
# pgpool auth
# TODO: generate a pool_passwd file
default['pgpool']['pgconf']['enable_pool_hba'] = true
default['pgpool']['pg_hba']['auth'] = [
  { type: 'local', db: 'all', user: 'all', addr: nil, method: 'md5' },
  { type: 'host', db: 'all', user: 'all', addr: '127.0.0.1/32', method: 'md5' },
  { type: 'host', db: 'all', user: 'all', addr: '0.0.0.0/0', method: 'md5' }
]


default['postgresql']['config']['data_directory'] = node['postgresql']['dir']
default['postgresql']['config']['listen_addresses'] = '*'
default['postgresql']['config']['port'] = 5432
default['postgresql']['config']['max_connections'] = 100
default['postgresql']['config']['shared_buffers'] = '128MB'
default['postgresql']['config']['dynamic_shared_memory_type'] = 'posix'
default['postgresql']['config']['log_destination'] = 'stderr'
default['postgresql']['config']['logging_collector'] = true
default['postgresql']['config']['log_filename'] = 'postgresql.log' # TODO: revisit log file naming
default['postgresql']['config']['log_truncate_on_rotation'] = true
default['postgresql']['config']['log_rotation_age'] = '1d'
default['postgresql']['config']['log_rotation_size'] = 0
# default['postgresql']['config']['log_line_prefix'] = '< %m >'
default['postgresql']['config']['log_timezone'] = 'UTC'
default['postgresql']['config']['datestyle'] = 'iso, mdy'
default['postgresql']['config']['timezone'] = 'UTC'
default['postgresql']['config']['lc_messages'] = 'en_US.UTF-8'
default['postgresql']['config']['lc_monetary'] = 'en_US.UTF-8'
default['postgresql']['config']['lc_numeric'] = 'en_US.UTF-8'
default['postgresql']['config']['lc_time'] = 'en_US.UTF-8'
default['postgresql']['config']['default_text_search_config'] = 'pg_catalog.english'

default['postgresql']['config']['effective_cache_size'] = "#{(node['memory']['total'].to_i / 2) / (1024)}MB"
default['postgresql']['config']['checkpoint_segments'] = '64'
default['postgresql']['config']['checkpoint_timeout'] = '5min'
default['postgresql']['config']['checkpoint_completion_target'] = '0.9'
default['postgresql']['config']['checkpoint_warning'] = '30s'

# pgpool recommended settings
default['postgresql']['config']['pgpool.pg_ctl'] = "#{node['postgresql']['bin_dir']}/pg_ctl"

# repmgr recommended settings
default['postgresql']['config']['hot_standby'] = 'on'
default['postgresql']['config']['wal_level'] = 'hot_standby'
default['postgresql']['config']['max_wal_senders'] = '20'
default['postgresql']['config']['max_replication_slots'] = '20'
default['postgresql']['config']['max_worker_processes'] = '20'
default['postgresql']['config']['archive_mode'] = 'on'
default['postgresql']['config']['archive_command'] = 'cd .'
default['postgresql']['config']['shared_preload_libraries'] = 'repmgr_funcs'

# TODO: allowing the entire internet is a terrible idea, assumes you've done firwewalls correctly
default['postgresql']['pg_hba'] = [
  {:type => 'local', :db => 'all', :user => 'postgres', :addr => nil, :method => 'ident'},
  {:type => 'local', :db => 'all', :user => 'all', :addr => nil, :method => 'ident'},
  {:type => 'host', :db => 'all', :user => 'all', :addr => '127.0.0.1/32', :method => 'md5'},
  {:type => 'host', :db => 'all', :user => 'all', :addr => '::1/128', :method => 'md5'},
  {:type => 'host', :db => 'all', :user => 'all', :addr => '0.0.0.0/0', :method => 'md5'},
  {:type => 'local', :db => 'replication', :user => 'postgres', :addr => nil, :method => 'ident'},
  {:type => 'host', :db => 'replication', :user => 'postgres', :addr => '127.0.0.1/32', :method => 'md5'},
  {:type => 'host', :db => 'replication', :user => 'postgres', :addr => '::1/128', :method => 'md5'},
  {:type => 'host', :db => 'replication', :user => 'replication', :addr => '0.0.0.0/0', :method => 'md5'}
]
