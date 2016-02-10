#!/bin/sh

# Run on VM to bootstrap the Foreman server
# Gary A. Stafford - 01/15/2015
# Modified - 08/19/2015
# Downgrade Puppet on box from 4.x to 3.x for Foreman 1.9 
# http://theforeman.org/manuals/1.9/index.html#3.1.2PuppetCompatibility

# Choose from 1.9, 1.10, latest, nightly, etc
DESIRED_FOREMAN_VERSION=latest

# Update system first
sudo yum update -y

if puppet agent --version | grep "^3." 2> /dev/null
then
    echo "Puppet Agent $(puppet agent --version) is already installed. Moving on..."
else
    echo "Puppet Agent $(puppet agent --version) installed. Replacing..."

    sudo rpm -ivh http://yum.puppetlabs.com/puppetlabs-release-el-7.noarch.rpm && \
    sudo yum -y erase puppet-agent && \
    sudo rm -f /etc/yum.repos.d/puppetlabs-pc1.repo && \
    sudo yum clean all
fi

if ps aux | grep "/usr/share/foreman" | grep -v grep 2> /dev/null
then
    echo "Foreman appears to all already be installed. Exiting..."
else
    sudo yum -y install epel-release http://yum.theforeman.org/releases/${DESIRED_FOREMAN_VERSION}/el7/x86_64/foreman-release.rpm && \
    sudo yum -y install foreman-installer nano nmap-ncat && \
    sudo foreman-installer \
	  --foreman-admin-password=admin \
	  --foreman-proxy-puppetrun=true \
	  --puppet-listen=true \
	  --puppet-hiera-config=/etc/puppet/hieradata/hiera.yaml

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

	# Enable auto-signing
	sudo echo "*.example.com" > /etc/puppet/autosign.conf
	
    # Run the Puppet agent on the Foreman host which will send the first Puppet report to Foreman,
    # automatically creating the host in Foreman's database
	# Should wait for foreman to be up
    sudo puppet agent --test --waitforcert=60

    # Optional, install some optional puppet modules on Foreman server to get started...
    # sudo puppet module install -i /etc/puppet/environments/production/modules locp-cassandra
	
	# Refresh foreman's class list
	sudo hammer --username admin --password admin proxy import-classes --id 1
fi