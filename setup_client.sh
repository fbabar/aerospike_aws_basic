#!/bin/bash

sudo yum -y update
ethtool -i eth0 | grep ixgbevf
sudo yum -y install java-1.8.0-openjdk-devel.x86_64 java-1.8.0-openjdk-javadoc.noarch
wget http://repos.fedorapeople.org/repos/dchen/apache-maven/epel-apache-maven.repo -O /etc/yum.repos.d/epel-apache-maven.repo
sed -i s/\$releasever/6/g /etc/yum.repos.d/epel-apache-maven.repo
sudo yum -y install apache-maven
wget --output-document aerospike-client-java.tgz http://www.aerospike.com/download/client/java/3.0.31/artifact/tgz
tar -zxvf aerospike-client-java.tgz
cd aerospike-client-java-*
export JAVA_HOME=$(readlink -f `which javac` | sed "s:bin/javac::")
./build_all
echo $1 > server_ip.txt
