# This file is part of the Resilient Cloud Native Infrastructure Testing (RCNIT) graduation thesis.

###############################################
#
# Environment setup: minimal text installation
#
###############################################

install
text
skipx
cdrom
eula --agreed
lang en_US.UTF-8
keyboard 'us'

############################################
#
# Network configuration: dynamic IP address
#
############################################

network  --bootproto=dhcp --device=ens3 --ipv6=auto --activate
timezone Europe/Amsterdam --isUtc

########################
#
# Partitioning: default
#
########################

bootloader --location=mbr
zerombr
clearpart --none
autopart --type=lvm

###########################################################################################
#
# User Accounts: plain text (user is administrator as well: --groups=wheel)
# Generate encrypted password: python -c 'import crypt; print(crypt.crypt("My Password"))'
# Or: openssl passwd -1 "My Password"
#
###########################################################################################

auth  --useshadow  --passalgo=sha512
rootpw --plaintext bashful
user --groups=wheel --name=bashful --password=bashful

############################################################
#
# SELinux and Firewalld; kubespray requires to disable them
#
############################################################

selinux --disabled
firewall --disabled