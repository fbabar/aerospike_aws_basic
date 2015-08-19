#!/bin/bash

JAVA_HOME=$(readlink -f `which javac` | sed "s:bin/javac::")
cd aerospike-client-java-*
server_ip=$(cat server_ip.txt)
echo "Starting benchmark on: $server_ip"
cd benchmarks/
./run_benchmarks -h $server_ip -p 3000 -n test -k 10000000 -S 1 -o S:100 -w RU,50 -z 90 -latency 10,1

