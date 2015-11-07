
# setup PGDG repositories and install Postgres client libraries
include_recipe 'postgresql::default'

include_recipe 'pgpool::default'

#  sysctl net.core.somaxconn - should be 256?
# http://jensd.be/591/linux/setup-a-redundant-postgresql-database-with-repmgr-and-pgpool
# http://linux.xvx.cz/2014/10/loadbalancing-of-postgresql-databases.html
# https://github.com/abessifi/pgpool-online-recovery
# http://www.pgpool.net/pgpool-web/contrib_docs/pgpool-II-3.5.pdf
