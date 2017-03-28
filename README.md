### Installing Foreman and Puppet Agent on Multiple VMs Using Vagrant and VirtualBox
Set up your environment:
1.	`vagrant plugin install vagrant-hostmanger`
1.	`vagrant plugin install vagrant-vbguest`
1.	`vagrant plugin install vagrant-triggers`
1.	`git clone git@github.com:mrwulf/vagrant-playground.git`
1.	`cd vagrant-playground/Workspace`
1.	Clone your puppet repository into Workspace/puppet. For example: `hg clone -b production <REPOSITORY-URL> puppet`
1.	Clone your hiera repository into Workspace/puppet. For example: `hg clone -b hiera <REPOSITORY-URL> hiera`
1.	`cd ..`
1.	`vagrant up theforeman.example.com`

### Iterate
1. Stand up the server/cluster you're working on. 
   * `vagrant up cassandra-01.example.com cassandra-02.example.com cassandra-03.example.com`
1. Make changes to puppet/hiera config.
1. Inspect and run puppet on nodes.
   * `vagrant ssh <node>.example.com`
   * `sudo puppet agent --test`
1. Profit! (Or start node over with `vagrant destroy <node>.example.com`)

### Where Things Are
* Foreman login:
   * https://theforeman.example.com/
   * admin/admin
* Foreman node definition: /nodes.js
* Other node definitions: /Workspace/nodes.js
* Hostgroup definitions: /Workspace/nodes.js

### Useful Multi-VM Commands
The use of the specific <machine> name is optional in most cases.
* `vagrant up <machine>`
* `vagrant reload <machine>`
* `vagrant destroy -f <machine> && vagrant up <machine>`
* `vagrant status <machine>`
* `vagrant ssh <machine>`
* `vagrant global-status`
