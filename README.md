# postgresql-cluster Chef cookbook

An MVP Chef cookbook for configuring a PostgreSQL cluster (9.4 WAL streaming with repmgr and pgpool), using Chef Provisioning

# Requirements

* ChefDK 0.9.0 or greater
  * Follow [the instructions](https://docs.chef.io/install_dk.html) to set ChefDK as your system Ruby and Gemset
* AWS configuration ( default: see [https://github.com/irvingpop/chef-provisioning-aws-helper])
* Vagrant and Virtualbox (optional)

# Status
Can currently configure Postgres master and standby in an automated fashion

# Using it

Starting up a cluster:
```bash
rake up
```

Connecting to your cluster nodes (on Vagrant):
```bash
cd vagrants ; vagrant ssh postgresql-bdr1.example.com
```

Destroying the cluster
```bash
rake destroy
```

Perform a rolling rebuild of the cluster:
```bash
rake rolling_rebuild
```

# TODO
