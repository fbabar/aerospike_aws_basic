#!/bin/bash

# Load configuration
. ./build_config.sh

# Locate the AMI id for Amazon Linux (use march 2015 as search criteria)
ami_id=$(ec2-describe-images -o amazon --region us-west-1  -F "architecture=x86_64" -F "block-device-mapping.volume-type=gp2" -F "image-type=machine" -F "root-device-type=ebs" -F "virtualization-type=hvm" -F "name=amzn-ami-hvm-2015.03.0*" | grep "ami-" | cut -f 2)

# If spot request file does not exist, create new requests
if [ ! -e $server_sir_file ]
then
  echo "Creating spot request for AMI: $ami_id"
  # Load subnet and security group ids from infra files
  subnet_id=$(cat $subnet_file)
  security_group_id=$(cat $sg_file)

  # Request our spot instances and save id to spot instance request file
  spot_request_id=$(ec2-request-spot-instances $ami_id -region $region -k $EC2_KEY_NAME -z $availability -t $server_instance_type -a ":0:$subnet_id:::$security_group_id" --placement-group $placement_group --associate-public-ip-address true -p $server_price | grep "sir-" | cut -f 2)
  echo "Created $spot_request_id"
  echo $spot_request_id > $server_sir_file
fi

# If we don't have a server, wait for one to be launched as result of our spot request
if [ ! -e $server_instance_file ]
then
  # Wait till fulfilled
  while ! ec2-describe-spot-instance-requests -region $region $spot_request_id | grep -q 'fulfilled'; do sleep 1; done

  # Tricky business - Will it always be column 8? AWS CLI has better options for returning only what you need
  server_instance_id=$(ec2-describe-spot-instance-requests -region $region $spot_request_id | grep active | awk '{ print $8 }')
  echo "Created instance: $server_instance_id"

  # Save server instance id to a file
  echo $server_instance_id > $server_instance_file
else
  # Read instance id from a pre-existing file
  server_instance_id=$(cat $server_instance_file)
fi

echo "Waiting for server to launch fully..."

while ! ec2-describe-instances -region $region $server_instance_id | grep -q 'running'; do sleep 1; done

echo "Connecting with instance $server_instance_id"

server_instance_address=$(ec2-describe-instances -region $region $server_instance_id | grep '^INSTANCE' | awk '{print $12}')
echo "Instance started: Host address is $server_instance_address"

echo Performing instance setup

while ! ssh-keyscan -t ecdsa $server_instance_address 2>/dev/null | grep -q $server_instance_address; do sleep 2; done
ssh-keyscan -t ecdsa $server_instance_address >> ~/.ssh/known_hosts 2>/dev/null
echo "Added $server_instance_address to known hosts"

# Is there a record of additional elastic network interfaces being attached?
if [ ! -e $eni_attachment_file ]
then
  # If not, load the ids of additional network interfaces
  eni_id_array=( $(cat $eni_file) )
  eni_size=${#eni_id_array[@]}

  # And attach them to this node
  echo "Attaching additional network interfaces ${eni_id_array[@]}"
  for (( i=1; i<=$eni_size; i++ )) ; do
    ec2-attach-network-interface -region $region ${eni_id_array[i-1]} -i $server_instance_id -d $i >> $eni_attachment_file
  done
fi

# Copy server setup script over and run it with sudo
scp -i $EC2_KEY_LOCATION setup_server.sh $EC2_USER@$server_instance_address:/tmp
ssh -i $EC2_KEY_LOCATION -t $EC2_USER@$server_instance_address 'sudo bash /tmp/setup_server.sh'

