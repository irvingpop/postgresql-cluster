
# populate all of the cluster nodes into the /etc/hosts file for name-based communication
found_nodes.each do |nodedata|
  hostsfile_entry extract_cluster_ip(nodedata) do
    hostname nodedata['name']
    aliases [ nodedata['fqdn'], nodedata['name'].split('.').first ]
    unique true
    comment 'Chef postgresql-cluster cookbook'
  end
end
