#!/usr/bin/env bash

# This file is part of the Resilient Cloud Native Infrastructure Testing (RCNIT) graduation thesis.

# Coloring the terminal
RED='\033[0;31m'
END='\033[0m'

# Declaring VM names & IPs
machines=("node1" "node2" "node3" "node4")
declare -a ips

echo -e "${RED}Creating RCNIT folder structure...${END}"
mkdir --verbose ~/2020_RCNIT/ISOs
mkdir --verbose ~/2020_RCNIT/VMs
echo -e "${RED}RCNIT folder structure created!${END}"

echo -e "${RED}Downloading necessary software...${END}"
sudo yum update -y
sudo yum install -y libvirt qemu-kvm virt-install virt-top libguestfs-tools bridge-utils virt-manager python-netaddr python36 python3-pip python-setuptools git wget epel-release
sudo pip3 install --upgrade pip
echo -e "${RED}Necessary software downloaded!${END}"

echo -e "${RED}Downloading CentOS 7 from Delft University of Technology to /ISOs...${END}"
wget --progress=bar --no-clobber -P ~/2020_RCNIT/ISOs/ "http://ftp.tudelft.nl/centos.org/7.7.1908/isos/x86_64/CentOS-7-x86_64-Minimal-1908.iso"
echo -e "${RED}CentOS 7 downloaded!${END}"

# Retrieve all variants: osinfo-query os | grep --ignore-case centos
# https://www.raymii.org/s/articles/virt-install_introduction_and_copy_paste_distro_install_commands.html
# http://atodorov.org/blog/2015/12/16/virtio-vs-rtl8139/
# https://earlruby.org/2018/12/use-iso-and-kickstart-files-to-automatically-create-vms/
for i in "${machines[@]}"; do
    echo -e
    echo -e "${RED}Creating $i...${END}"
    sudo virt-install \
        --name "$i" \
        --virt-type kvm \
        --ram=4096 \
        --vcpus=2 \
        --os-type=Linux \
        --os-variant=centos7.0 \
        --disk path="$HOME"/2020_RCNIT/VMs/"$i".qcow2,bus=virtio,size=20 \
        --graphics spice \
        --location ~/2020_RCNIT/ISOs/CentOS-7-x86_64-Minimal-1908.iso \
        --network network=default,model=rtl8139 \
        --noreboot \
        --initrd-inject=kickstart.ks \
        --extra-args "ks=file:/kickstart.ks"
done
echo -e "${RED}VMs created!${END}"

echo -e "${RED}Creating fresh-install snapshots...${END}"
for i in "${machines[@]}"; do
    sudo virsh snapshot-create-as --domain "$i" \
        --name "fresh-install" \
        --description "Fresh CentOS 7 installation"
done
echo -e "${RED}Snapshots created!${END}"

~/2020_RCNIT/Scripts/maintenance/./start-machines.sh

echo -e "${RED}Configuring SSH...${END}"
ssh-keygen -f ~/.ssh/rcnit_key -N "" <<<n
for i in "${machines[@]}"; do
    # This allows connecting to machines through ssh using the command 'ssh <hostname>'
    echo "Host $i" | tee -a "${HOME}/.ssh/config"
    echo "	Hostname " | tr -d '\n' | tee -a "${HOME}/.ssh/config" && sudo virsh domifaddr "$i" | awk 'FNR==3 {print $4}' | rev | cut -c4- | rev | tee -a "${HOME}/.ssh/config"
    echo "	IdentityFile ~/.ssh/rcnit_key" | tee -a "${HOME}/.ssh/config"
    echo "	User bashful" | tee -a "${HOME}/.ssh/config"
    # sshpass uses the local super user password
    # https://unix.stackexchange.com/questions/230084/send-the-password-through-stdin-in-ssh-copy-id
    sshpass -p "bashful" ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/rcnit_key "$i"
    ssh -o StrictHostKeyChecking=no "$i" "chmod 700 .ssh; chmod 640 .ssh/authorized_keys"
    # Put all IPs into array; used by 'CONFIG_FILE' for configuring kubespray's hosts.yml
    ips+=("$(sudo virsh domifaddr "$i" | awk 'FNR==3 {print $4}' | rev | cut -c4- | rev)")
done
# Copying the SSH key allows passwordless login between VMs; necessary for kubespray
# Copying the config & known_hosts files allows for 'ssh <hostname>' login without host key checking
for i in "${machines[@]}"; do
    scp ~/.ssh/config "$i":.ssh/
    scp ~/.ssh/known_hosts "$i":.ssh/
    scp ~/.ssh/rcnit_key "$i":.ssh/
    scp ~/.ssh/rcnit_key.pub "$i":.ssh/
done
echo -e "${RED}SSH configured!${END}"

echo -e "${RED}Configuring VMs...${END}"
for i in "${machines[@]}"; do
    ssh -tt "$i" 'echo "bashful" | sudo -Sv && bash -s' <<EOF
	echo "Downloading necessary software"
	sudo yum update -y
	sudo yum install -y python-netaddr python36 python3-pip python-setuptools git wget epel-release
	sudo pip3 install --upgrade pip
	git clone https://github.com/kubernetes-incubator/kubespray.git
	cd kubespray || exit
	pip3 install --user -r requirements.txt
	echo "Necessary software downloaded"
	echo "Enabling passwordless sudo"
	sudo sed -i 's/# %wheel/%wheel/g' /etc/sudoers
	echo "Passwordless sudo enabled"
	echo "Enablling IPv4 forwarding, necessary for kubespray"
	echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.conf
	echo "IPv4 forwarding enabled"
	echo "Disabling swap, necessary for kubespray"
	sudo sed -i.bak -r 's/(.+ swap .+)/#\1/' /etc/fstab
	sudo swapoff -av
	echo "Swap disabled"
	exit
EOF
done
echo -e "${RED}VMs configured!${END}"

~/2020_RCNIT/Scripts/maintenance/./stop-machines.sh
~/2020_RCNIT/Scripts/maintenance/./kill-machines.sh
~/2020_RCNIT/Scripts/maintenance/./start-machines.sh

echo -e "${RED}Configuring kubespray...${END}"
cd ~/2020_RCNIT/ || exit
git clone https://github.com/kubernetes-incubator/kubespray.git
cd ~/2020_RCNIT/kubespray/ || exit
pip3 install --user -r requirements.txt
cp -rfpv ~/2020_RCNIT/kubespray/inventory/sample/ ~/2020_RCNIT/kubespray/inventory/rcnit/
# Run a default hosts.yml (has 2 masters, 2-node scheduler, and a 3-node etcd)
# Otherwise, you need to edit hosts.yml manually
# https://github.com/kubernetes-sigs/kubespray/blob/master/contrib/inventory_builder/inventory.py
CONFIG_FILE=~/2020_RCNIT/kubespray/inventory/rcnit/hosts.yml python3 ~/2020_RCNIT/kubespray/contrib/inventory_builder/inventory.py "${ips[@]}"
echo -e "${RED}Kubespray configured!${END}"

echo -e "${RED}Deploying Kubernetes...${END}"
# The kubeadm token for joining nodes has a 24h expiration period
# There will be some errors and warnings popping up that don't affect the deployment
# https://www.youtube.com/watch?v=CJ5G4GpqDy0
ansible-playbook -i ~/2020_RCNIT/kubespray/inventory/rcnit/hosts.yml ~/2020_RCNIT/kubespray/cluster.yml --become --become-user=root
# Installing kubectl on localhost
sudo curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
# Giving the first master kubectl access
ssh -tt node1 'echo "bashful" | sudo -Sv && bash -s' <<EOF
	mkdir ~/.kube
	sudo cp --verbose /etc/kubernetes/admin.conf ~/.kube/
	cd ~/.kube
	sudo mv admin.conf config
	sudo chown --recursive bashful /home/bashful/
	sudo service kubelet restart &&	exit
EOF
# Giving localhost kubectl access
scp node1:~/.kube/config ~/2020_RCNIT/
mkdir ~/.kube
mv ~/2020_RCNIT/config ~/.kube/
# https://stackoverflow.com/questions/48228534/kubernetes-dashboard-access-using-config-file-not-enough-data-to-create-auth-inf
TOKEN=$(kubectl -n kube-system describe secret default | awk '$1=="token:"{print $2}')
kubectl config set-credentials kubernetes-admin --token="${TOKEN}"
~/2020_RCNIT/Scripts/maintenance/./stop-machines.sh
~/2020_RCNIT/Scripts/maintenance/./kill-machines.sh
echo -e "${RED}Kubernetes deployed!${END}"

echo -e "${RED}Creating fresh-kubernetes snapshots...${END}"
for i in "${machines[@]}"; do
    sudo virsh snapshot-create-as --domain "$i" \
        --name "fresh-kubernetes" \
        --description "Fresh Kubernetes installation"
done
echo -e "${RED}Snapshots created!${END}"

~/2020_RCNIT/Scripts/maintenance/./start-machines.sh
