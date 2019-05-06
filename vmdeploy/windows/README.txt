DESCRIPTION:
The files and directories within this directory are used for provisioning and performing basic customization of a Windows Server VM on vSphere 6.5+ using Ansible. They cater to my requirement for provisioning Database (MSSQL) VMs wherein we provision 4 drives (K:\, L:\, S:\, T:\) for backup, log, data and temp in addition to base OS and application drives (C:\ and D:\ drives).

STRUCTURE:

windows
├── files
│   └── servers.csv
├── README.txt
├── scripts
│   ├── addDisk.bat
│   └── addDisk.ps1
├── vars
│   ├── main.yml
│   ├── secrets.yml
│   └── servers.yml
├── vmdeploy.sh
└── vmdeploy.yml


PRE-REQUISITES:
(1) A Windows Server 2012 R2 or later VM Template on VMware (tested with ESXi 6.5+) with scripts (addDisk.bat and addDisk.ps1) embedded. These scripts cater to my needs for drives and can be DANGEROUS (format drives). Test properly.
(2) Ansible 2.8+ on the control server with connectivity to tcp/443 on the vCenter.
(3) secrets.yml created with ansible-vault and containing variables referenced in main.yml (e.g. all variables prefixed with 'vault_')

USAGE: 
Provide input of VMs to be provisioned in CSV format (servers.csv) and execute as shown below:

./vmdeploy.sh
