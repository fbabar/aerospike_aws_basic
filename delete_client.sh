#!/bin/bash

. ./build_config.sh

if [ -e $client_instance_file ]
then
  client_instance_id_array=( $(cat $client_instance_file) )
  client_array_size=${#client_instance_id_array[@]}

  echo "Deleting instances: ${client_instance_id_array[@]}"
  ec2-terminate-instances -region $region ${client_instance_id_array[@]}

  # We do this one instance at a time to ensure cleanup of partial launches
  for (( i=1; i<=${client_array_size}; i++ )); do
    client_instance_id=${client_instance_id_array[i-1]}
    #echo "Deleting instance: $client_instance_id"
    #ec2-terminate-instances -region $region $client_instance_id

    # Are there circumstances where this loop may get stuck? apparently yes. If we try to delete non existent or very old deleted instances
    while ! ec2-describe-instances -region $region $client_instance_id | grep -q 'terminated'; do sleep 1; done
  done

  mv $client_instance_file "${client_instance_file}.bak"
  mv $client_sir_file "${client_sir_file}.bak"
  sleep 1
fi

if [ -e $client_sir_file ]
then
  client_sir_id_array=( $(cat $client_sir_file) )

  request_list=${client_sir_id_array[*]}
  request_length=${#request_list[@]}

  echo "Deleting spot instance requests $request_list"
  ec2-cancel-spot-instance-requests -region $region $request_list
  mv $client_sir_file "${client_sir_file}.bak"
  sleep 1
fi

