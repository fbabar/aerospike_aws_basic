#!/bin/bash

. ./build_config.sh

if [ ! -e $vpc_file ]
then
  vpc_id=$(ec2-create-vpc -region $region $cidr | awk '{print $2}')
  echo "Created vpc: $vpc_id"
  echo $vpc_id > $vpc_file
  while ! ec2-describe-vpcs -region $region $vpc_id | grep -q 'available'; do sleep 1; done
else
  vpc_id=$(cat $vpc_file)
  echo "Using existing vpc: $vpc_id"
fi

if [ ! -e $gw_file ]
then
  gw_id=$(ec2-create-internet-gateway -region $region | cut -f 2)
  echo "Created internet gateway $gw_id"
  echo $gw_id > $gw_file

  ec2-attach-internet-gateway -region $region $gw_id -c $vpc_id
else
  gw_id=$(cat $gw_file)
  echo "Using existing internet gateway $gw_id"
fi

if [ ! -e $subnet_file ]
then
  subnet_id=$(ec2-create-subnet -region $region -z $availability -c $vpc_id -i 10.2.0.0/24 | awk '{print $2}')
  echo "Created subnet: $subnet_id"
  echo $subnet_id > $subnet_file
  while ! ec2-describe-subnets -region $region $subnet_id | grep -q 'available'; do sleep 1; done
else
  subnet_id=$(cat $subnet_file)
  echo "Using existing subnet: $subnet_id"
fi

if [ ! -e $route_file ]
then
  route_table_id=$(ec2-create-route-table -region $region $vpc_id | grep ROUTETABLE | cut -f 2)
  echo "Created route table $route_table_id"
  echo $route_table_id > $route_file

  ec2-associate-route-table -region $region $route_table_id -s $subnet_id
  ec2-create-route -region $region $route_table_id -r $inter_webternet -g $gw_id
else
  route_table_id=$(cat $route_file)
  echo "Using existing routing table $route_table_id"
fi

if [ ! -e $sg_file ]
then
  security_group_id=$(ec2-create-group -region $region $security_group -d bench -c $vpc_id | awk '{print $2}')
  echo "Created security group: $security_group_id"
  echo $security_group_id > $sg_file
  sleep 1

  ec2-authorize -region $region $security_group_id -P TCP -p 3000-3003 -s $inter_webternet
  ec2-authorize -region $region $security_group_id -P TCP -p 22 -s $inter_webternet
  ec2-authorize -region $region $security_group_id -P TCP -p 8001 -s $inter_webternet
  ec2-create-placement-group -region $region -s cluster $placement_group
else
  security_group_id=$(cat $sg_file)
  echo "Using existing security_group: $security_group_id"
fi

if [ ! -e $eni_file ]
then
  # Create three additional network interfaces for a total of 4 on the server
  ec2-create-network-interface -region $region -g $security_group_id $subnet_id | grep "^NETWORK" | cut -f 2 >> $eni_file
  ec2-create-network-interface -region $region -g $security_group_id $subnet_id | grep "^NETWORK" | cut -f 2 >> $eni_file
  ec2-create-network-interface -region $region -g $security_group_id $subnet_id | grep "^NETWORK" | cut -f 2 >> $eni_file
else
  eni_id_array=( $(cat $eni_file) )
  echo "Using existing network interfaces ${eni_id_array[@]}"
fi

