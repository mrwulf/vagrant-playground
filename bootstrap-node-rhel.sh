#!/bin/sh

# Run on VM to bootstrap the Puppet Agent RHEL-based Linux nodes

# Update system first
sudo yum update -y --nogpgcheck
PUPPET_CONF=/etc/puppetlabs/puppet/puppet.conf

if grep "#provisioned" $PUPPET_CONF > /dev/null 2>&1
then
    echo "Puppet Agent already provisioned. Moving on..."
else
  echo "Configuring Puppet Agent..."

  PUPPET=`which puppet`
  if $PUPPET agent --version
  then
    echo "Puppet Agent $(puppet agent --version) is already installed. Moving on..."
  else
    sudo yum -y install puppet-agent --nogpgcheck
    PUPPET=`which puppet`
  fi

    # sudo rpm -ivh http://yum.puppetlabs.com/puppetlabs-release-el-6.noarch.rpm && \
    # sudo yum -y erase puppet-agent && \
    # sudo rm -f /etc/yum.repos.d/puppetlabs-pc1.repo && \
    # sudo yum clean all && \
    # sudo yum -y install puppet

    # Add agent section to /etc/puppet/puppet.conf
    # Easier to set run interval to 120s for testing (reset to 30m for normal use)
    # https://docs.puppetlabs.com/puppet/3.8/reference/config_about_settings.html
    echo "" | sudo tee --append $PUPPET_CONF 2> /dev/null && \
    echo "    server = theforeman.example.com" | sudo tee --append $PUPPET_CONF 2> /dev/null && \
    echo "    runinterval = 1800s" | sudo tee --append $PUPPET_CONF 2> /dev/null && \
    echo "#provisioned" | sudo tee --append $PUPPET_CONF 2> /dev/null

    # Unless you have Foreman autosign certs, each agent will hang on this step until you manually
    # sign each cert in the Foreman UI (Infrastrucutre -> Smart Proxies -> Certificates -> Sign)
    # Alternative, run manually on each host, after provisioning is complete...
    sudo $PUPPET agent --test --waitforcert=60 || true

	# Enable puppet and make sure the agent is running
	sudo $PUPPET resource service puppet ensure=running enable=true
fi

if [ ! -f /usr/bin/puppet ]
then
  sudo ln -s /opt/puppetlabs/bin/puppet /usr/bin/puppet
fi
