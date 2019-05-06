
.
├── files
│   └── servers.csv      # This is the input file containing specific details for the VMs to be deployed
├── scripts
│   └── joinDomain.sh    # This script is embedded in the RHEL VM Template at /opt/VMBuild/bin/joinDomain.sh
├── vars
│   ├── main.yml         # Main Variables file
│   ├── secrets.yml      # File containing credentials created using ansible-vault. Excluded from git.
│   └── servers.yml      # File generated from servers.csv by vmdeploy.sh
├── vmdeploy.sh          # Main Deployment script
└── vmdeploy.yml         # Main Deployment playbook


PRE-REQUISITES:
(1) A RHEL 7 VM Template on VMware (tested with ESXi 6.5+) with /opt/VMBuild/bin/joinDomain.sh tweaked to meet your needs and all the required packages (realmd,oddjob,oddjob-mkhomedir,sssd,adcli,samba-common-tools).
(2) Ansible 2.7+ on the control server with connectivity to tcp/443 on the vCenter.
(3) secrets.yml created with ansible-vault and containing variables referenced in main.yml (e.g. all variables prefixed with 'vault_')

NOTE: If you do not wish to join the server to an AD Domain, then simply remove the vmware_vm_shell module from the vmdeploy.yml playbook.


EXECUTION:

./vmdeploy.sh
