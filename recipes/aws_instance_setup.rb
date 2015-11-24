myhostname = node.name

# change my hostname to node name
execute 'force-hostname-fqdn' do
  command "hostname #{myhostname}"
  action :run
  not_if { myhostname == `/bin/hostname`.chomp }
end

file '/etc/hostname' do
  action :create
  owner 'root'
  group 'root'
  mode '0644'
  content "#{myhostname}\n"
end

# put it in the hostsfile
hostsfile_entry node['ipaddress'] do
  hostname myhostname
  aliases [ myhostname.split('.').first ]
  not_if "grep #{node.name} /etc/hosts"
end

ec2_ephemeral_mount node['postgresql']['home'] do
  mount_point node['postgresql']['home']
end
