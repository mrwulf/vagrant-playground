# Builds single Foreman server and
# multiple Puppet Agent Nodes using JSON config file
# read vm and configurations from JSON files
CONFIG_FILE = 'nodes.json'
FOREMAN     = 'theforeman.example.com'
WORKSPACE   = 'Workspace'
PUPPET_REPO = "#{WORKSPACE}/puppet/"
HIERA_REPO  = "#{WORKSPACE}/puppet/data"

ENV["VAGRANT_DEFAULT_PROVIDER"] = 'virtualbox'

# Helpful functions
def multi_merge(*args)
  args.compact.reduce( {}, &:merge! )
end

def deep_symbolize(obj)
    return obj.inject({}){|memo,(k,v)| memo[k.intern] =  deep_symbolize(v); memo} if obj.is_a? Hash
    return obj.inject([]){|memo,v    | memo           << deep_symbolize(v); memo} if obj.is_a? Array
    return obj
end

base_config = deep_symbolize JSON.parse(File.read(CONFIG_FILE))
workspace_config = deep_symbolize JSON.parse(File.read("#{WORKSPACE}/#{CONFIG_FILE}")) ; {}

$nodes_config = multi_merge( base_config[:nodes], workspace_config[:nodes] )
$hostgroup_config = multi_merge( base_config[:hostgroups], workspace_config[:hostgroups] )
$globalparms_config = multi_merge( base_config[:global_parameters], workspace_config[:global_parameters] )
$defaultnode_config = multi_merge( base_config[:default_node], workspace_config[:default_node] )

def node_config(name)
  node_defaultconfig   = $defaultnode_config
  node_values          = $nodes_config[ name.intern ]
  node_hostgroupconfig = {}
  if node_values[ :hostgroup ] and $hostgroup_config[ node_values[ :hostgroup ].intern ] then
    node_hostgroupconfig = $hostgroup_config[ node_values[:hostgroup].intern ][ :default_node ]
  end

  multi_merge( node_defaultconfig,
               node_hostgroupconfig,
               node_values )
end

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  $nodes_config.each do |node, values|
    node_name   = node.to_s
    node_values = node_config( node_name )

    node_values[:autostart] = true if node_values[:autostart].nil?

    config.vbguest.auto_update = true
    config.hostmanager.enabled = false
    config.hostmanager.manage_host = true
    config.hostmanager.ignore_private_ip = false
    config.hostmanager.include_offline = false
    config.timezone.value = "America/Los_Angeles"
    #config.windows.set_work_network = true
    #config.winrm.usuername = "vagrant"
    #config.winrm.password = "vagrant"

    config.vm.define node_name, autostart: node_values[:autostart] do |boxconfig|
      short_name = node_name[/([^.]*)/,0]

      boxconfig.vm.box = node_values[:box]
      boxconfig.vm.hostname = node_values[:box].include?('win') ? short_name : node_name
      boxconfig.vm.network "private_network", ip: node_values[:ip], netmask: "255.255.192.0" # removed for linux #, name: 'eth1'
      boxconfig.hostmanager.aliases = [ short_name, node_values[:box] ]

      #if node_values[:box].include?('win') then
      #  #boxconfig.hostmanager.manage_guest = false
      #  boxconfig.vm.communicator = "winrm"
      #  boxconfig.vm.network "forwarded_port", guest: 5985, host: 5985, id: "winrm", auto_correct: true, host_ip: "127.0.0.1"
      #end

      # configures all forwarding ports in JSON array
      node_values[:ports].each do |port|
        boxconfig.vm.network "forwarded_port",
          host_ip: "172.0.0.1",
          host:  port[:host],
          guest: port[:guest],
          id:    port[:id]
      end

      # configures synced folders
      node_values[:mounts].each do |mount|
        boxconfig.vm.synced_folder mount[:host], mount[:guest]
      end

      boxconfig.vm.provider :virtualbox do |vb|
        vb.customize ["modifyvm", :id, "--memory", node_values[:memory]]
        vb.customize ["modifyvm", :id, "--name", node_name]
        vb.gui = false
      end

      boxconfig.vm.provision :hostmanager
      boxconfig.vm.provision :shell, :path => node_values[:bootstrap]

      # Manage foreman hostgroups
      if node_name == FOREMAN then
        boxconfig.trigger.after [:up, :resume, :provision] do |mytrigger|
          trigger_remote_command = ""
          $hostgroup_config.each do |hostgroup_name, hostgroup_values|
            hostgroup_command = "sudo hammer hostgroup create --name \"#{hostgroup_name}\""

            hostgroup_values.each do |option, value|
              next if option == :parameters
              next if option == :default_node
              hostgroup_command = "#{hostgroup_command} --#{option} \"#{value}\""
            end
            trigger_remote_command += "#{hostgroup_command} ; "
            if hostgroup_values[:parameters].respond_to?(:each) then
              hostgroup_values[:parameters].each do |hostgroup_parameter, value|
                trigger_remote_command += "sudo hammer hostgroup set-parameter --hostgroup \"#{hostgroup_name}\" --name \"#{hostgroup_parameter}\" --value \"#{value}\" ; "
              end
            end
          end
          $globalparms_config.each do |globalparm, globalvalue|
            trigger_remote_command += "sudo hammer global-parameter set --name \"#{globalparm}\" --value \"#{globalvalue}\" ; "
          end

          mytrigger.info = "Setting Up Hostgroups and Global Parameters"
          mytrigger.run_remote = {inline: "#{trigger_remote_command} true"} unless trigger_remote_command.empty?
        end
      else
        boxconfig.vm.synced_folder ".", "/vagrant", type: "virtualbox"
        #config.vm.linked_clone = true

        # check that foreman is running... vagrant status | grep theforeman\W*\w+running &&
        # Add/Remove nodes from hostgroups
        boxconfig.trigger.after [:up, :provision] do |mytrigger|
          trigger_command = ""
          if !node_values[:hostgroup].nil? then
            trigger_command += "vagrant ssh #{FOREMAN} -c 'sudo hammer host update --name #{node_name} --hostgroup #{node_values[:hostgroup]}' ; "
          end
          if node_values[:host_parameters] then
            params = ""
            node_values[:host_parameters].each do |param_key, param_value|
              params += "#{param_key}=#{param_value}"
            end
            trigger_command += "vagrant ssh #{FOREMAN} -c 'sudo hammer host update --name #{node_name} --parameters #{params}' ; "
          end
          if node_values[:classes] then
            trigger_command += "vagrant ssh #{FOREMAN} -c 'sudo hammer host update --name #{node_name} --puppet-classes #{node_values[:classes]}' ; "
          end
          trigger_command += "vagrant ssh #{node_name} -c 'sudo puppet agent --test' ; "

          mytrigger.info = "Setting up this host in foreman"
          mytrigger.run = {inline: "bash -c \"#{trigger_command} \""} unless trigger_command.empty?
        end

        boxconfig.trigger.after :destroy do |mytrigger|
          trigger_command = ""
          trigger_command += "vagrant ssh -c \"sudo hammer host delete --name #{node_name}\" #{FOREMAN} ; "
          trigger_command += "vagrant ssh -c \"sudo puppet cert clean #{node_name}\" #{FOREMAN} ; "

          mytrigger.info = "Cleaning up this host in foreman"
          mytrigger.run = {inline: "bash -c '#{trigger_command}'"} unless trigger_command.empty?
        end
      end
    end
  end
end
