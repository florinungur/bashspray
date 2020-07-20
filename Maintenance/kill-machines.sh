#!/bin/bash

# This file is part of the Resilient Cloud Native Infrastructure Testing (RCNIT) graduation thesis.

# Coloring the terminal
RED='\033[0;31m'
END='\033[0m'

# Declaring VM names
machines=( "node1" "node2" "node3" "node4" )

for i in "${machines[@]}"; do
	sudo virsh destroy "$i"
done
sleep 3
echo -e "${RED}VMs killed!${END}"