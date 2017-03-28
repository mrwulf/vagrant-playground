#!/bin/sh

# Run on VM to bootstrap the Foreman server

# Choose from 1.9, 1.10, latest, nightly, etc
DESIRED_FOREMAN_VERSION=latest

# Update system first
sudo yum -y install deltarpm
sudo yum makecache && sudo yum update -y

if ps aux | grep "/usr/share/foreman" | grep -v grep 2> /dev/null
then
    echo "Foreman appears to all already be installed. Exiting..."
else
    sudo yum -y install deltarpm
    sudo yum -y remove puppet-server puppet
    sudo rpm -Uvh https://yum.puppetlabs.com/puppetlabs-release-pc1-el-7.noarch.rpm
    sudo yum -y install epel-release http://yum.theforeman.org/releases/${DESIRED_FOREMAN_VERSION}/el7/x86_64/foreman-release.rpm && \
    sudo yum -y install puppetserver puppet-agent puppet-agent-oauth foreman-installer nano nmap-ncat htop && \
    sudo foreman-installer --foreman-admin-password=admin \
                           --puppet-server-max-active-instances=1 \
                           --puppet-server-jvm-min-heap-size=512M \
                           --puppet-server-jvm-max-heap-size=512M \
                           --puppet-server-implementation=puppetserver \
                           --puppet-autosign=true \
                           --puppet-autosign-entries="*.example.com" \
                           --puppet-hiera-config=/etc/puppetlabs/code/hieradata/hiera.yaml

    # Set-up firewall
    # https://www.digitalocean.com/community/tutorials/additional-recommended-steps-for-new-centos-7-servers
    sudo firewall-cmd --permanent --add-service=http
    sudo firewall-cmd --permanent --add-service=https
    sudo firewall-cmd --permanent --add-port=69/tcp
    sudo firewall-cmd --permanent --add-port=67-69/udp
    sudo firewall-cmd --permanent --add-port=53/tcp
    sudo firewall-cmd --permanent --add-port=53/udp
    sudo firewall-cmd --permanent --add-port=8443/tcp
    sudo firewall-cmd --permanent --add-port=8140/tcp

    sudo firewall-cmd --reload
    sudo systemctl enable firewalld

    # Run the Puppet agent on the Foreman host which will send the first Puppet report to Foreman,
    # automatically creating the host in Foreman's database
	# Should wait for foreman to be up
    sudo puppet agent --test --waitforcert=60

    # Optional, install some optional puppet modules on Foreman server to get started...
    # sudo puppet module install -i /etc/puppet/environments/production/modules locp-cassandra

  # Make it more likely that the class import will succeed
  sudo service puppetserver restart
  sudo hammer settings set --name proxy_request_timeout --value 300
  sudo service foreman-proxy restart
  sudo hammer environment create --name production
fi
# Refresh foreman's class list everytime we start
sudo hammer proxy import-classes --id 1 --environment production || true
