#!/bin/bash
# Author: mrkips - Cybergavin (http://mrgav.in)
# v1.0 - 24th Feb 2019
# Rudimentary script to create variables for an ansible provisioning playbook and execute the playbook 
#
###############################################################################################
vmdeploy_playbook=vmdeploy.yml
serverlist=files/servers.csv
varsfile=vars/servers.yml
#
# Create server variables file for ansible
#
cat<<EOF > $varsfile
---
new_vms:
EOF
for line in `awk 'NR>1' $serverlist`
 do
   IFS=, read -ra fields <<< $line
   nm=`echo ${fields[2]} | cut -d '/' -f2`
   if [ $nm -lt 24 ]; then
      echo "Invalid network ${fields[2]} . CIDR /24 to /32 only allowed"
   fi
   my_nm=255.255.255.$(( 256 - (2**(32-nm)) ))
   my_gw=`echo ${fields[2]} | cut -d '/' -f1 | awk -F. '{print $1"."$2"."$3"."($4 + 1)}'`
   echo "  - {name: ${fields[0]}, ip: ${fields[1]}, gw: $my_gw, nm: $my_nm, nicpg: ${fields[3]}, cpu: ${fields[4]}, mem: $(( fields[5] * 1024 )), ds: ${fields[6]}}"
done >> $varsfile
#
# Execute ansible playbook 
#
ansible-playbook --vault-id @prompt $vmdeploy_playbook
