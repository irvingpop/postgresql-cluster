# encoding: utf-8

module PgClusterHelpers
  def master_node
    results = search(:node, "tags:pg_master",
      filter_result: {
        'name' => [ 'name' ],
        'fqdn' => [ 'fqdn' ],
      }
    )
    results.first['name']
  end

  # first, populate /etc/hosts from search results
  def extract_cluster_ip(node_results)
    use_interface = node['postgresql-cluster']['use_interface']
    node_results['network_interfaces'][use_interface]['addresses']
      .select { |k,v| v['family'] == 'inet' }.keys
  end

  def found_nodes
    search(:node, "name:postgresql-*",
      filter_result: {
        'name' => [ 'name' ],
        'fqdn' => [ 'fqdn' ],
        'network_interfaces' => [ 'network', 'interfaces' ]
      }
    ).reject { |nodedata| nodedata['network_interfaces'].nil? } #not if no interface data
      .reject { |nodedata| nodedata['name'] == node.name } # not if it's me
  end
end

# Magic to make these methods injected into the recipe_dsl
Chef::Recipe.send(:include, PgClusterHelpers)
Chef::Provider.send(:include, PgClusterHelpers)
Chef::Resource.send(:include, PgClusterHelpers)
