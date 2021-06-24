#!/bin/bash
# Script to alter firewall bootstart to include specific users on dynamic addresses

FWSCRIPT=/root/bin/fwinit_ovh-eaux-fw.sh
HOSTS_ALLOW=/etc/hosts.allow
LOG_FILE=/root/log/ipcheck.log

timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

# Check if user exists andf returns current IP
check_if_user_exists() {
  local user=$1
  user_ip=$(grep "${user}=" $FWSCRIPT | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}') >>$LOG_FILE 2>&1
  if [ "$user_ip" ]; then
    echo "$user_ip"
  else
    echo 0
  fi
}

update_fw_file() {
  local user=$1
  local current_ip=$2
  echo "$(timestamp) [Info] IP for ${user} has changed. Updating FW script with ${current_ip}..." >>$LOG_FILE 2>&1
  sed -i "/${user}=/c ${user}=\"${current_ip}\"" $FWSCRIPT >>$LOG_FILE 2>&1
}

update_hosts_file() {
  local old_ip=$1
  local current_ip=$2
  echo "$(timestamp) [Info] Updating <hosts.allow> from old IP ${old_ip} to the new IP ${current_ip}..." >>$LOG_FILE 2>&1
  sed -i "/ALL:${old_ip}/c ALL:${current_ip}" $HOSTS_ALLOW >>$LOG_FILE 2>&1
}

# Receives $1 as fqdn, $2 as user string in file.
if [ "$1" ] && [ "$2" ]; then
  fqdn="$1"
  user="$2"
  current_ip=$(nslookup "${fqdn}" | grep -Po '[^\t]\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b' | awk '{print $1}') >>$LOG_FILE 2>&1
  if [ ! "$current_ip" ]; then
    echo "$(timestamp) [Error] no IP could be retrieved. Exiting script..." >>$LOG_FILE 2>&1
    exit
  fi
  current_rule_ip=$(check_if_user_exists $user)
  if [ "$current_ip" = "$current_rule_ip" ]; then
    echo "$(timestamp) [Info] IP ${current_ip} for ${user} hasn't changed. Terminating script..." >>$LOG_FILE 2>&1
    exit
  else
    update_fw_file "$user" "$current_ip"
    update_hosts_file "$current_rule_ip" "$current_ip"
    echo "$(timestamp) [Info] Running the updated firewall boot script..." >>$LOG_FILE 2>&1
    $FWSCRIPT >>$LOG_FILE 2>&1
  fi
fi
