# -*- mode: ruby -*-
# vi: set ft=ruby :

# Builds single Foreman server and
# multiple Puppet Agent Nodes using JSON config file
# read vm and configurations from JSON files
CONFIG_FILE = "nodes.json"

base_config = JSON.parse(File.read(CONFIG_FILE))
workspace_config = JSON.parse(File.read("Workspace/#{CONFIG_FILE}")) || {}

nodes_config = base_config['nodes'] || {}
nodes_config.merge!(workspace_config['nodes'])

hostgroup_config = base_config['hostgroups'] || {}
hostgroup_config.merge!(workspace_config['hostgroups'])

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
	
	# Manage foreman hostgroups
	if node_name == 'theforeman.example.com' then
        config.trigger.after :up, :vm => [node_name] do |trigger|
		  hostgroup_config.each do |hostgroup|
		    hostgroup_command = "hammer -u admin -p admin hostgroup create --name \"#{hostgroup[0]}\""
			hostgroup[1].each do |option|
			  hostgroup_command = "#{hostgroup_command} --#{option[0]} \"#{option[1]}\""
			end
			run_remote hostgroup_command
		  end
        end
	else
	  # Add/Remove nodes from hostgroups
      if !node_values[':hostgroup'].nil? then
        config.trigger.after :up, :vm => [node_name] do |trigger|
		  run "vagrant ssh theforeman.example.com -- -t \"hammer -u admin -p admin host update --name #{node_name} --hostgroup #{node_values[':hostgroup']}\""
		  run_remote "sudo puppet agent --test || true"
        end
      end

      config.trigger.after :destroy, :vm => [node_name] do |trigger|
        run "vagrant ssh theforeman.example.com -- -t \"hammer -u admin -p admin host delete --name #{node_name}\""
        run "vagrant ssh theforeman.example.com -- -t \"sudo puppet cert clean #{node_name}\""
      end
	end
	
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
