#!/bin/bash

# Update the client and install java
echo "Installing java..."
sudo yum -y update
sudo yum -y install java-1.8.0-openjdk-devel.x86_64 java-1.8.0-openjdk-javadoc.noarch

# High I/O node?
if ! ethtool -i eth0 | grep -q ixgbevf ; then
  echo "Node configuration does not support high speed I/O on ethernet"
fi

# Installing maven on Amzon AMI is yucky
wget http://repos.fedorapeople.org/repos/dchen/apache-maven/epel-apache-maven.repo -O /etc/yum.repos.d/epel-apache-maven.repo
sed -i s/\$releasever/6/g /etc/yum.repos.d/epel-apache-maven.repo
sudo yum -y install apache-maven > /dev/null 2>&1

# Download and build aerospike benchmark tool
echo "Installing aerospike benchmark tool"
wget --output-document aerospike-client-java.tgz http://www.aerospike.com/download/client/java/3.0.31/artifact/tgz > /dev/null 2>&1
tar -zxvf aerospike-client-java.tgz > /dev/null 2>&1
cd aerospike-client-java-*
export JAVA_HOME=$(readlink -f `which javac` | sed "s:bin/javac::")
./build_all > /dev/null 2>&1
echo $1 > server_ip.txt
