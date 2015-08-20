#!/bin/bash

# Update the server and install python (needed for aerospike)
yum -y update > /dev/null 2>&1
yum install python -y > /dev/null 2>&1

# High I/O node?
if ! ethtool -i eth0 | grep -q ixgbevf ; then
  echo "Node configuration does not support high speed I/O on ethernet"
fi

# Retrieve a known version of aerospike server
wget --output-document=aerospike.tgz http://www.aerospike.com/download/server/3.5.15/artifact/el6 > /dev/null 2>&1
tar xf aerospike.tgz > /dev/null 2>&1
rm aerospike.tgz
cd aerospike-server-community-3.5.15-el6/
echo "Installing aerospike server"
./asinstall > /dev/null 2>&1

# get afterburner and helper
wget https://raw.githubusercontent.com/aerospike/aerospike-server/master/tools/afterburner/afterburner.sh > /dev/null 2>&1
wget https://raw.githubusercontent.com/aerospike/aerospike-server/master/tools/afterburner/helper_afterburner.sh > /dev/null 2>&1
chmod +x afterburner.sh
chmod +x helper_afterburner.sh

echo "Optiminzing IRQs"
yes | ./afterburner.sh > /dev/null 2>&1
rm afterburner.sh
rm helper_afterburner.sh

# Get a list of IRQs for each of the ethernet interfaces
irq_script="for i in {0..3}; do grep eth\$i-TxRx /proc/interrupts | awk '{printf \"  %s\n\", \$1}' | sed -e 's/:$//'; done"
irq_array=( $(eval $irq_script) )
irq_count=${#irq_array[@]}

# Now assign SMP affinity for IRQs to first 8 cores (2 IRQs per interface, 4 interfaces)
processor=1
for (( i=0; i<$irq_count; i++ )); do
  hex_processor=$(printf "%x" $processor)
  echo "Setting processor $hex_processor affinity for handling irq ${irq_array[i]}"
  echo $hex_processor > "/proc/irq/${irq_array[i]}/smp_affinity"
  let "processor <<= 1"
done

echo "Ethernet interfaces:"
for i in {0..3}; do echo -n eth$i; ifconfig eth$i | grep "inet addr"; done

service aerospike start
sleep 2
server_pid=$(cat /var/run/aerospike/asd.pid)
taskset -p ffffff00 $server_pid
