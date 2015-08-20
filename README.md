Aerospike Stress Test On AWS
============================

Aerospike stress testing package for AWS.  This package contains scripts for building the necessary high performance infrastructure, server and clients to stress test aerospike in AWS.

Setup
-----

* build_config.sh:    Loads configuration for use by other scripts.
* build_control.sh:   Builds up controller node, by installing java and AWS EC2 API tools
* build_infra.sh:     Builds necessary infrastructure, inlcuding vpn, subnet, firewall and routes.
* build_server.sh:    Builds a high performance server using built infrastructure and deploys aerospike
* build_client.sh:    Build 4 clients to stress aerospike and deploys aerospike benchmark tool to each
* build_all.sh:       Builds everything

Teardown
--------

* delete_infra.sh:    Releases infrastructure, inlcuding vpn, subnet, firewall and routes.
* delete_server.sh:   Terminates server instance
* delete_client.sh:   Terminates client nodes
* delete_all.sh:      Releases all infrastructure and terminates all nodes


Other
-----

* run_client.sh:      Runs benchmark on client node (needs to run remotely)
* run_all.sh:         Loads IP addresses of client nodes and runs benchmark in parallel for 20 seconds

Prerequisites
-------------

* AWS access key in build_config.sh
* AWS secret key in build_config.sh
* AWS private key for launching and connecting to nodes

Usage instructions
------------------

    ./build_all.sh  <- Builds everything
    ./run_all.sh    <- Runs benchmarks
    ./delete_all.sh <- Releases all resources
