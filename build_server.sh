#!/bin/bash

. ./build_config.sh

ami_id=$(ec2-describe-images -o amazon --region us-west-1  -F "architecture=x86_64" -F "block-device-mapping.volume-type=gp2" -F "image-type=machine" -F "root-device-type=ebs" -F "virtualization-type=hvm" -F "name=amzn-ami-hvm-2015.03.0*" | grep "ami-" | cut -f 2)

if [ ! -e $server_sir_file ]
then
  echo "Creating spot request for AMI: $ami_id"

  subnet_id=$(cat $subnet_file)
  security_group_id=$(cat $sg_file)

  spot_request_id=$(ec2-request-spot-instances $ami_id -region $region -k $EC2_KEY_NAME -z $availability -t $server_instance_type -a ":0:$subnet_id:::$security_group_id" --placement-group $placement_group --associate-public-ip-address true -p $server_price | grep "sir-" | cut -f 2)
  echo "Created $spot_request_id"
  echo $spot_request_id > $server_sir_file
fi

if [ ! -e $server_instance_file ]
then
  while ! ec2-describe-spot-instance-requests -region $region $spot_request_id | grep -q 'fulfilled'; do sleep 1; done
  server_instance_id=$(ec2-describe-spot-instance-requests -region $region $spot_request_id | grep active | awk '{ print $8 }')
  echo "Created instance: $server_instance_id"
  echo $server_instance_id > $server_instance_file
else
  server_instance_id=$(cat $server_instance_file)
fi

echo "Connecting with instance $server_instance_id"

while ! ec2-describe-instances -region $region $server_instance_id | grep -q 'running'; do sleep 1; done

server_instance_address=$(ec2-describe-instances -region $region $server_instance_id | grep '^INSTANCE' | awk '{print $12}')
echo "Instance started: Host address is $server_instance_address"

echo Performing instance setup

while ! ssh-keyscan -t ecdsa $server_instance_address 2>/dev/null | grep -q $server_instance_address; do sleep 2; done
ssh-keyscan -t ecdsa $server_instance_address >> ~/.ssh/known_hosts 2>/dev/null
echo "Added $server_instance_address to known hosts"

if [ ! -e $eni_attachment_file ]
then
  eni_id_array=( $(cat $eni_file) )
  eni_size=${#eni_id_array[@]}

  echo "Attaching additional network interfaces ${eni_id_array[@]}"

  for (( i=1; i<=$eni_size; i++ )) ; do
    ec2-attach-network-interface -region $region ${eni_id_array[i-1]} -i $server_instance_id -d $i >> $eni_attachment_file
  done
fi

scp -i $EC2_KEY_LOCATION setup_server.sh $EC2_USER@$server_instance_address:/tmp
ssh -i $EC2_KEY_LOCATION -t $EC2_USER@$server_instance_address 'sudo bash /tmp/setup_server.sh'

