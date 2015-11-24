# Generate postgres SSH key for failover control

# from chef-provisioning-aws-helper - expects a key to be at srcdir/.chef/keys/username@srcdir
# see: https://github.com/irvingpop/chef-provisioning-aws-helper/blob/master/recipes/default.rb#L15-L47
keypair_name  = node['postgresql-cluster']['postgres_keypair_name']
key_dir       = Chef::Config.private_key_paths.first
private_key   = File.join(key_dir, keypair_name)
public_key    = File.join(key_dir, "#{keypair_name}.pub")

# create ssh key and write to disk
unless Dir.exist?(key_dir) && File.exist?(private_key) && File.exist?(public_key)

  log "Generating SSH keypair #{keypair_name} for you at #{key_dir}"

  directory key_dir do
    mode '0700'
    recursive true
    action :create
  end

  execute 'generate key' do
    command "ssh-keygen -f #{private_key} -N '' -C #{node['postgresql-cluster']['postgres_keypair_name']}@#{node['postgresql-cluster']['domain_name']}"
    action :run
    creates private_key
  end

end

# now store the pubkey and private key in a databag
# TODO: use encrypted databags and/or vault for this
ruby_block "store_ssh_keys_for_#{keypair_name}" do
  block do
    # because ruby blocks have their own variable scope - maybe use note attributes?
    keypair_name  = node['postgresql-cluster']['postgres_keypair_name']
    key_dir       = Chef::Config.private_key_paths.first
    private_key   = File.join(key_dir, keypair_name)
    public_key    = File.join(key_dir, "#{keypair_name}.pub")

    databag = Chef::DataBag.new
    databag.name(node['postgresql-cluster']['sshkey_databag'])
    databag.save

    databag_item = Chef::DataBagItem.new
    databag_item.data_bag(node['postgresql-cluster']['sshkey_databag'])
    databag_item.raw_data = {
      'id' => keypair_name,
      'public_key' => ::File.read(public_key),
      'private_key' => ::File.read(private_key)
    }
    databag_item.save
  end
end

include_recipe "postgresql-cluster::provision_#{node['postgresql-cluster']['provisioning']['driver']}"
