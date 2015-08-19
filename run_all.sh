#!/bin/bash

. ./build_config.sh

echo $client_instance_file

client_instance_array=( $(cat $client_instance_file) )
client_instance_count=${#client_instance_array[@]}

echo "Running benchmark on $client_instance_count nodes (${client_instance_array[@]})"

for (( i=0; i<${client_instance_count}; i++ )); do
  client_instance_id=${client_instance_array[i]}
  client_instance_address=$(ec2-describe-instances -region $region $client_instance_id | grep '^INSTANCE' | awk '{print $12}')
  echo "Starting benchmark for $client_instance_address"

  scp -i $EC2_KEY_LOCATION run_client.sh $EC2_USER@$client_instance_address:/tmp
  (ssh -i $EC2_KEY_LOCATION $EC2_USER@$client_instance_address 'bash /tmp/run_client.sh') & child_pid=$!
  (sleep 20 && kill -9 $child_pid) &
done

