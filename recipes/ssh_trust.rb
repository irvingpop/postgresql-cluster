# sets up ssh trusts for the postgres user based on the keys created in the provision recipe
sshkeys = data_bag_item(node['postgresql-cluster']['sshkey_databag'], node['postgresql-cluster']['postgres_keypair_name'])

postgres_ssh_dir = ::File.join(node['postgresql']['home'], '.ssh')
postgres_ssh_priv_key = ::File.join(postgres_ssh_dir, 'id_rsa')
postgres_ssh_pub_key = ::File.join(postgres_ssh_dir, 'id_rsa.pub')
postgres_ssh_authorized_keys = ::File.join(postgres_ssh_dir, 'authorized_keys')

directory postgres_ssh_dir do
  owner 'postgres'
  mode 00755
  recursive true
  action :create
end

file postgres_ssh_priv_key do
  owner 'postgres'
  mode 00600
  action :create
  content sshkeys['private_key']
end

file postgres_ssh_pub_key do
  owner 'postgres'
  mode 00644
  action :create
  content sshkeys['public_key']
end

file postgres_ssh_authorized_keys do
  owner 'postgres'
  mode 00644
  action :create
  content sshkeys['public_key']
end
