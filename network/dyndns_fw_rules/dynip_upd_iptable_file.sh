#!/bin/bash
# Script to alter firewall bootstart to include specific users on dynamic addresses

FWSCRIPT=/root/bin/fwinit_ovh-eaux-fw.sh
HOSTS_ALLOW=/etc/hosts.allow
LOG_FILE=/root/log/ddns_ipcheck.log

timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

# Check if user exists andf returns current IP
check_if_user_exists() {
  local user=$1
  local user_ip=$(grep "${user}=" $FWSCRIPT | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}')
  if [ "$user_ip" ]; then
    echo "$user_ip"
  else
    echo 0
  fi
}

update_fw_file() {
  local user=$1
  local current_ip=$2
  echo "$(timestamp) [Info] IP for ${user} has changed. Updating FW script with ${current_ip}..." 2>&1 | tee -a $LOG_FILE
  sed -i "/${user}=/c ${user}=\"${current_ip}\"" $FWSCRIPT 2>&1 | tee -a $LOG_FILE
}

update_hosts_file() {
  local old_ip=$1
  local current_ip=$2
  echo "$(timestamp) [Info] Updating <hosts.allow> from old IP ${old_ip} to the new IP ${current_ip}..." 2>&1 | tee -a $LOG_FILE
  sed -i "/ALL:${old_ip}/c ALL:${current_ip}" $HOSTS_ALLOW 2>&1 | tee -a $LOG_FILE
}

# Receives $1 as fqdn, $2 as user string in file.
if [ "$1" ] && [ "$2" ]; then
  FQDN="$1"
  USER="$2"
  CURRENT_IP=$(nslookup "${FQDN}" | grep -Po '[^\t]\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b' | awk '{print $1}')
  if [ ! "$CURRENT_IP" ]; then
    echo "$(timestamp) [Error] no IP could be retrieved. Exiting script..." 2>&1 | tee -a $LOG_FILE
    exit
  fi
  current_rule_ip=$(check_if_user_exists $USER)
  if [ "$CURRENT_IP" = "$current_rule_ip" ]; then
    echo "$(timestamp) [Info] IP ${CURRENT_IP} for ${USER} hasn't changed. Terminating script..." 2>&1 | tee -a $LOG_FILE
    exit
  else
    update_fw_file "$USER" "$CURRENT_IP"
    update_hosts_file "$current_rule_ip" "$CURRENT_IP"
    echo "$(timestamp) [Info] Running the updated firewall boot script..." 2>&1 | tee -a $LOG_FILE
    $FWSCRIPT 2>&1 | tee -a $LOG_FILE
  fi
fi
