#!/bin/bash

# This file is part of the Resilient Cloud Native Infrastructure Testing (RCNIT) graduation thesis.

# Coloring the terminal
RED='\033[0;31m'
END='\033[0m'

# Declaring VM names
machines=( "node1" "node2" "node3" "node4" )

for i in "${machines[@]}"; do
	sudo virsh snapshot-revert --domain "$i" --snapshotname fresh-install --running --force
done
sleep 20
echo -e "${BLUE}VMs reverted!${END}"