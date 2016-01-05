# -*- mode: ruby -*-
# vi: set ft=ruby :

# Builds single Foreman server and
# multiple Puppet Agent Nodes using JSON config file
# read vm and configurations from JSON files
nodes_config = (JSON.parse(File.read("nodes.json")))['nodes']
nodes_config.merge!((JSON.parse(File.read("Workspace/nodes.json")))['nodes']) if File.exist?("Workspace/nodes.json")

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  nodes_config.each do |node|
    node_name   = node[0] # name of node
    node_values = node[1] # content of node

	node_values[':autostart'] = true if node_values[':autostart'].nil?

    config.vbguest.auto_update = true
    
    config.hostmanager.enabled = true
    config.hostmanager.manage_host = true
    config.hostmanager.ignore_private_ip = false
    config.hostmanager.include_offline = true

    config.vm.define node_name, autostart: node_values[':autostart'] do |boxconfig|

      boxconfig.vm.box = node_values[':box']
      boxconfig.vm.hostname = node_name
	  
      boxconfig.vm.network :private_network, ip: node_values[':ip']
	  
  	  # configures all forwarding ports in JSON array
      ports = node_values['ports']
      ports.each do |port|
        boxconfig.vm.network :forwarded_port,
          host:  port[':host'],
          guest: port[':guest'],
          id:    port[':id']
      end

	  # configures synced folders
	  mounts = node_values['mounts']
	  mounts.each do |mount|
	    boxconfig.vm.synced_folder mount[':host'], mount[':guest']
	  end
	  
      boxconfig.vm.provider :virtualbox do |vb|
        vb.customize ["modifyvm", :id, "--memory", node_values[':memory']]
        vb.customize ["modifyvm", :id, "--name", node_name]
      end

      boxconfig.vm.provision :shell, 
							 :path => node_values[':bootstrap']
	  
    end
  end
end
