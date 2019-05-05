#!/bin/bash
# Created By: mrkips - http://mrgav.in
# Created On: 3rd March 2019
# Description: Join a RHEL 7 server to a Microsoft Active Directory Domain
#
#############################################################################
#
# Determine Script Location
#
if [ -n "`dirname $0 | grep '^/'`" ]; then
   SCRIPT_LOCATION=`dirname $0`
elif [ -n "`dirname $0 | grep '^..'`" ]; then
     cd `dirname $0`
     SCRIPT_LOCATION=$PWD
     cd - > /dev/null
else
     SCRIPT_LOCATION=`echo ${PWD}/\`dirname $0\` | sed 's#\/\.$##g'`
fi
SCRIPT_NAME=`basename $0`
if [ ! -f ${SCRIPT_LOCATION}/${SCRIPT_NAME} ]; then
   printf "\n`date '+%Y%m%d_%H%M'` : ERROR : Could not detect script location and/or name. Check and test script. Exiting...\n"
   exit 1
fi
function logMessage # Log to logfile/alarmfile
{
LOGTIME=`date '+%d-%b-%Y : %H:%M:%S'`
if [ "$1" = "INFO" ]; then
   printf "$LOGTIME : ${GREEN}$1${NC} : $2\n\n"
elif [ "$1" = "ERROR" ]; then
   printf "$LOGTIME : ${RED}$1${NC} : $2\n\n"
fi
if [ -s $LOGFILE ]; then
   printf "$LOGTIME : $1 : $2\n\n" >> $LOGFILE
else
   printf "$LOGTIME : $1 : $2\n\n" > $LOGFILE
fi
}
function helpme
{
cat<<EOF

$(echo -e "${GREEN}${SCRIPT_NAME} -b <AD Bind User> -p <AD Bind Password> [-u '<AD user>'] [-g '<AD group>']${NC}")

where,
     AD Bind User = the AD user used to join the server to AD
     AD Bind Password = the password for the above user
     AD user   = the AD user (e.g. 'jblog.admin') requiring access to the server.
     AD group  = the AD group (e.g. 'sysadmins') requiring access to the server.

EOF
exit 100
}
#
# Main
#
#
# Variables
#
GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m" # No Color
CONFDIR=${SCRIPT_LOCATION}/../conf
LOGDIR=${SCRIPT_LOCATION}/../logs
KEYDIR=${SCRIPT_LOCATION}/../keys
BACKUPDIR=${SCRIPT_LOCATION}/../backup
LOGFILE=${LOGDIR}/${SCRIPT_NAME%%.*}.log
CONFFILE=${CONFDIR}/${SCRIPT_NAME%%.*}.cfg
DOMAIN="satlab"
DOMAIN_FQDN="satlab.home"
unset DOMAIN_BIND DOMAIN_BIND_PASS DOMAIN_USER DOMAIN_GROUP
#
# Parse input parameters
#
while getopts ":b:p:u:g:h" opt; do
        case $opt in
                b)      DOMAIN_BIND=$OPTARG
                        ;;
                p)      DOMAIN_BIND_PASS=$OPTARG
                        ;;
                u)      DOMAIN_USER=$OPTARG
                        ;;
                g)      DOMAIN_GROUP=$OPTARG
                        ;;
                h)      helpme
                        ;;
                \?)     echo "Invalid option: -$OPTARG"
                        helpme
                        ;;
                :)      echo "Option -$OPTARG requires an argument."
                        helpme
                        ;;
        esac
done
shift $((OPTIND-1))
#
# Join server to AD Domain
#
if [ -n "${DOMAIN_BIND}" -a -n "${DOMAIN_BIND_PASS}" -a -z "`realm list`" ]; then
   # Install required packages
   logMessage "INFO" "Installing required packages for AD Domain membership ....."
   reqpkgs=`realm discover $DOMAIN_FQDN | grep "required-package" | awk -F':' '{printf $2" "}'`
   yum -y install $reqpkgs
   echo "${DOMAIN_BIND_PASS}" | realm join $DOMAIN_FQDN -U ${DOMAIN_BIND}
   if [ $? -eq 0 ]; then
        logMessage "INFO" "Joined $HOST_NAME to the $DOMAIN domain."
   else
        logMessage "ERROR" "Failed to join $HOST_NAME to the $DOMAIN domain."
   fi
   systemctl enable sssd && cp -f ${CONFDIR}/sssd.conf /etc/sssd/sssd.conf
   if [ $? -eq 0 ]; then
        logMessage "INFO" "Enabled and configured sssd."
   else
        logMessage "ERROR" "Failed to enable/configure sssd."
   fi
   realm deny --all && realm permit -g "${DOMAIN}\\admins" && echo "%admins     ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers
   if [ $? -eq 0 ]; then
        logMessage "INFO" "Configured sysadmin access to $DOMAIN domain."
   else
        logMessage "ERROR" "Failed to configure sysadmin access to the $DOMAIN domain."
   fi
   if [ -n "${DOMAIN_USER}" ]; then
      realm permit "${DOMAIN}\\${DOMAIN_USER}"
        if [ $? -eq 0 ]; then
                logMessage "INFO" "Configured access for ${DOMAIN_USER} to $DOMAIN domain."
        else
                logMessage "ERROR" "Failed to configure access for ${DOMAIN_USER} to the $DOMAIN domain."
        fi
   fi
   if [ -n "${DOMAIN_GROUP}" ]; then
      realm permit -g "${DOMAIN}\\${DOMAIN_GROUP}"
        if [ $? -eq 0 ]; then
                logMessage "INFO" "Configured access for ${DOMAIN_GROUP} to $DOMAIN domain."
        else
                logMessage "ERROR" "Failed to configure access for ${DOMAIN_GROUP} to the $DOMAIN domain."
        fi
   fi
   sed -i "s/PasswordAuthentication.*/PasswordAuthentication=yes/g" /etc/ssh/sshd_config
   if [ $? -eq 0 ]; then
           logMessage "INFO" "Configured SSH to allow Password Authentication."
   else
           logMessage "ERROR" "Failed to configure SSH to allow Password Authentication."
   fi
else
           logMessage "ERROR" "Failed to join $HOST_NAME to the $DOMAIN domain. Either the required credentials are missing/wrong or $HOST_NAME is already joined to an AD Domain."
fi
