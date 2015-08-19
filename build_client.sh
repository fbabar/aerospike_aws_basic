#!/bin/bash

. ./build_config.sh

ami_id=$(ec2-describe-images -o amazon --region us-west-1  -F "architecture=x86_64" -F "block-device-mapping.volume-type=gp2" -F "image-type=machine" -F "root-device-type=ebs" -F "virtualization-type=hvm" -F "name=amzn-ami-hvm-2015.03.0*" | grep "ami-" | cut -f 2)

# cleanup partial instance requests later
if [ ! -e $client_sir_file ]
then
  echo "Creating spot request for AMI: $ami_id"

  subnet_id=$(cat $subnet_file)
  security_group_id=$(cat $sg_file)

  client_spot_request_id_array=( $(ec2-request-spot-instances $ami_id -region $region -k $EC2_KEY_NAME -n $client_count -z $availability -t $client_instance_type -a ":0:$subnet_id:::$security_group_id" --placement-group $placement_group --associate-public-ip-address true -p $client_price | grep "sir-" | cut -f 2) )

  # get length of spot request id array
  Len=${#client_spot_request_id_array[@]}
  for (( i=1; i<=${Len}; i++ ));
  do
    echo "Created ${client_spot_request_id_array[i-1]}"
    echo ${client_spot_request_id_array[i-1]} >> $client_sir_file
  done
else
  # Try to reuse the existing requests
  client_spot_request_id_array=( $(cat $client_sir_file) )
  Len=${#client_spot_request_id_array[@]}
  for (( i=1; i<=${Len}; i++ ));
  do
    echo "Re-using ${client_spot_request_id_array[i-1]}"
  done
fi

if [ ! -e $client_instance_file ]
then
  request_list=${client_spot_request_id_array[*]}
  request_length=${#client_spot_request_id_array[@]}
  echo "Checking spot requests: $request_list"
  test_value="failed"

  while true; do
    test_array=( $(ec2-describe-spot-instance-requests -region $region $request_list) )
    
    if [[ " ${test_array[@]} " =~ " ${test_value} " ]]; then
      echo "Spot request failed"
      exit 1
    fi
    fulfilled_array=( $(ec2-describe-spot-instance-requests -region $region $request_list | grep active | awk '{ print $8 }') )
    fulfilled_size=${#fulfilled_array[@]}
    echo "Waiting on fulfillment..."
    if [ $fulfilled_size == $request_length ]; then
      break
    fi
    sleep 1
  done

  fulfilled_array=( $(ec2-describe-spot-instance-requests -region $region $request_list | grep active | awk '{ print $8 }') )
else
  fulfilled_array=( $(cat $client_instance_file) )
fi

server_instance_id=$(cat $server_instance_file)
server_ip_array=( $(ec2-describe-instances -region us-west-1 $server_instance_id | grep -w "^NIC" | cut -f 7) )
server_ip_count=${#server_ip_array[@]}

fulfilled_size=${#fulfilled_array[@]}
for (( i=1; i<=${fulfilled_size}; i++ )); do
  client_instance_id=${fulfilled_array[i-1]}
  echo "Created instance: $client_instance_id"

  while ! ec2-describe-instances -region $region $iclient_instance_id | grep -q 'running'; do sleep 1; done
  client_instance_address=$(ec2-describe-instances -region $region $client_instance_id | grep '^INSTANCE' | awk '{print $12}')
  echo "Instance started: Host address is $client_instance_address"

  echo Performing instance setup
  while ! ssh-keyscan -t ecdsa $client_instance_address 2>/dev/null | grep -q $client_instance_address; do sleep 2; done
  ssh-keyscan -t ecdsa $client_instance_address >> ~/.ssh/known_hosts 2>/dev/null
  echo "Added $client_instance_address to known hosts"

  scp -i $EC2_KEY_LOCATION setup_client.sh $EC2_USER@$client_instance_address:/tmp
  let ip_index=(${i}-1)%$server_ip_count
  server_ip=${server_ip_array[ip_index]}
  ssh -i $EC2_KEY_LOCATION -t $EC2_USER@$client_instance_address "sudo bash /tmp/setup_client.sh $server_ip"
  echo $client_instance_id >> $client_instance_file
done
