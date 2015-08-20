#!/bin/bash

# Load configuration
. ./build_config.sh

# If there is a server (file with server instance id present)
if [ -e $server_instance_file ]
then
  server_instance_id=$(cat $server_instance_file)
  echo "Deleting instance: $server_instance_id"
  ec2-terminate-instances -region $region $server_instance_id

  while ! ec2-describe-instances -region $region $server_instance_id | grep -q 'terminated'; do sleep 1; done

  mv $server_instance_file "${server_instance_file}.bak"
  mv $server_sir_file "${server_sir_file}.bak"
  sleep 1
fi

# Cleanup any outstanding spot instance requests
if [ -e $server_sir_file ]
then
  server_sir_id=$(cat $server_sir_file)
  echo "Deleting spot instance request $server_sir_id"
  ec2-cancel-spot-instance-requests -region $region $server_sir_id
  mv $server_sir_file "${server_sir_file}.bak"
  sleep 1
fi

