#!/bin/bash

# Setup this node to run ec2 api tools
./build_control.sh

# Build vpc, subnet and firewall infrastructure
./build_infra.sh

# Build server node(s)
./build_server.sh

# Build client nodes
./build_client.sh

