# Bashspray

This project is a set of six Bash scripts that set up a default [Kubernetes](https://kubernetes.io/docs/concepts/overview/what-is-kubernetes/) cluster with [kubespray](https://github.com/kubernetes-sigs/kubespray).

This project was created because I could not find one like it on the web. A similar solution is YOTRON's [Local Kubernetes Cluster](https://github.com/yotron/local-kubernetes-cluster).

Yes, the scripts are ugly, but they work. KISS.

## Assumptions

- File path root: `$HOME/2020_RCNIT/Scripts`
    - Create these folders and put [Deployment](Deployment) and [Maintenance](Maintenance) in them.
- OS: CentOS 7/8
- Scripts are executable: `chmod +x <script.sh>`

## Folder structure

Before:
```text
. ($HOME/2020_RCNIT)
├── Scripts
	├── Deployment
	│   ├── deploy.sh
	│   ├── kickstart.ks
	├── Maintenance
		├── kill-machines.sh
		├── revert-machines-to-fresh-install.sh
		├── revert-machines-to-fresh-kubernetes.sh
		├── start-machines.sh
		└── stop-machines.sh
```

After:
```text
.
├── ISOs
│   ├── CentOS-7-x86_64-Minimal-1908.iso
├── kubespray (big folder)
├── Scripts
	├── Deployment
	│   ├── deploy.sh
	│   ├── kickstart.ks
	├── Maintenance
		├── kill-machines.sh
		├── revert-machines-to-fresh-install.sh
		├── revert-machines-to-fresh-kubernetes.sh
		├── start-machines.sh
		└── stop-machines.sh
└── VMs
    ├── node1.qcow2
    ├── node2.qcow2
    ├── node3.qcow2
    └── node4.qcow2
```

## Credentials

The root password, admin name, and admin password are all `bashful`. These can be changed in [kickstart.ks](Deployment/kickstart.ks).
If these credentials are changed, they need to be manually changed in [deploy.sh](Deployment/deploy.sh) too.

The VMs names are hardcoded in every script as `node1`, `node2`, `node3`, and `node4` under the variable `machines`.

## How to use

Run [deploy.sh](Deployment/deploy.sh) to set up the VMs and the Kubernetes cluster. This script will:

1.	Set up the project folder structure.
2.	Download all the necessary software.
3.	Use `virt-install` and [kickstart.ks](Deployment/kickstart.ks) to create 4 VMs with CentOS 7.
4.	Make snapshots of the fresh OS installation.
5.	Configure passwordless SSH access to each VM.
6.	Set up k8s on each VM using kubespray.
7.	Set up kubectl on `localhost` and `node1`.
8.	Make snapshots of the fresh Kubernetes installation.

The only manual inputs needed are pressing `Enter` at the end of each OS installation (which will close the Virt Viewer windows) and entering the local and remote sudo passwords several times.

The purpose of the maintenance scripts is to help speed up development – it would take longer to manually force power-off (i.e. kill), revert to previous snapshots, start, or shut down machines.
