#!/bin/bash
set -x

# Proxy
export HTTPS_PROXY=${internet_http_proxy_url}
export HTTP_PROXY=${internet_http_proxy_url}
export NO_PROXY=${internet_http_no_proxy},127.0.0.1,localhost,0.0.0.0
export https_proxy=${internet_http_proxy_url}
export http_proxy=${internet_http_proxy_url}
export no_proxy=${internet_http_no_proxy},127.0.0.1,localhost,0.0.0.0

# Install required packages to start git-ops-based auto-configuratiom
if which yum > /dev/null 2>&1 ; then
	sed -i 's/gpgcheck=1/gpgcheck=1\nproxy=_none_/g' /etc/yum.repos.d/centos.repo

	if [ ! -z "$HTTP_PROXY" ] ; then
		grep -q proxy= /etc/yum.conf || echo "proxy=$HTTP_PROXY" >> /etc/yum.conf
	fi

	yum install --assumeyes ansible git jq > /dev/null
else
	apt update > /dev/null
	apt -y install ansible git jq python3-swiftclient python3-openstackclient > /dev/null
fi

# DNS: Populate /etc/hosts
if [ ! -z "${static_hosts}" ] ; then
	echo ${static_hosts} > /tmp/static_hosts
	cat /tmp/static_hosts \
	| perl -pe 's/\[|\]|{|}//g' \
	|  tr ',' '\n' \
	| awk -F: '{print $2,$1}' \
	| awk '{print $1,$2}' \
	>> /etc/hosts
fi

# Configure ansible to work without an entire environment set
sed -i 's/~/\/root/' /etc/ansible/ansible.cfg
sed -i 's/^#remote_tmp/remote_tmp/' /etc/ansible/ansible.cfg
sed -i 's/^#local_tmp/remote_tmp/' /etc/ansible/ansible.cfg

# Create local facts folder
mkdir -p /etc/ansible/facts.d

# Clone the bootstrap git repository
export REPO_PATH=/root/appliance
export ETC_PATH=$REPO_PATH/etc
export PLAYBOOK=$REPO_PATH/logs/graylog.appliance.playbook.yml

## Set the Openstack credentials
export OS_AUTH_URL="${os_auth_url}"
export OS_PROJECT_ID=$(awk -F'"' '/project_id/ {print $4}' /run/cloud-init/instance-data.json)
export OS_USER_DOMAIN_NAME="Default"
export OS_USERNAME="${os_username}"
export OS_PASSWORD="${os_password}"
export OS_REGION_NAME="${os_region_name}"
export OS_INTERFACE=public
export OS_IDENTITY_API_VERSION=3

# Swift container
export LOGS_CONTAINER=${logs_container}

# Set the volumes' IDs
export CONTAINERS_VOLUME=${cinder_containers_volume}
export ELASTICSEARCH_VOLUME=${cinder_elasticsearch_volume}
export GRAYLOG_VOLUME=${cinder_graylog_volume}

# Set the Graylog credentials
export GRAYLOG_ADMIN_NAME="${graylog_admin_name}"
export GRAYLOG_ADMIN_PASSWORD="${graylog_admin_password}"
# Set Graylog endpoint
export GRAYLOG_ENDPOINT_URL="${graylog_endpoint_url}"

# Set Consul variables
export CONSUL_USAGE="${consul_usage}"
export CONSUL_DNS_DOMAIN="${consul_dns_domain}"
export CONSUL_DATACENTER="${consul_datacenter}"
export CONSUL_ENCRYPT="${consul_encrypt}"
export CONSUL_DNS_SERVER="${consul_dns_server}"

# Set InfluxDB variables
export INFLUXDB_USAGE="${influxdb_usage}"
export INFLUXDB_ENDPOINT="${influxdb_endpoint}"
export INFLUXDB_TOKEN="${influxdb_token}"
export INFLUXDB_BUCKET="${influxdb_bucket}"

# Test proxy and Openstack endpoint
test -z $HTTP_PROXY || curl -vks HTTP_PROXY > /dev/null
openstack server list

# Set NTP variables
export NTP_SERVER=${ntp_server}

# Autoconf the appliance
curl -vks ${git_repo_url} > /dev/null
git clone -b ${git_repo_checkout} ${git_repo_url} $REPO_PATH || exit 1

. $REPO_PATH/logs/graylog.appliance.autoconf.sh

# Stop secure shell
systemctl stop ssh
systemctl disable ssh
