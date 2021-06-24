#!/bin/bash
# Script to alter ufw rules to include specific users on dynamic addresses

# Debug
#HOSTS_ALLOW=/root/log/hosts.allow
#UFW="ufw --dry-run"

HOSTS_ALLOW=/etc/hosts.allow
LOG_FILE=/root/log/ddns_ipcheck.log
IP_FILE_PATH=~/log/
IP_FILE_SFX=do_not_delete
UFW="ufw"

timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

# Updates the hosts.allow file with the latest IP
update_hosts_file() {
  local current_ip="$1"
  local old_ip="$2"
  echo "$(timestamp) [Info] Updating <hosts.allow> from old IP ${old_ip} to the new IP ${current_ip}..." 2>&1 | tee -a $LOG_FILE
  local rule_exists=$(grep -o "^ALL:${old_ip}" $HOSTS_ALLOW)
  if [ "$rule_exists" != 0 ]; then
    sed -i "/ALL:${old_ip}/c ALL:${current_ip}" $HOSTS_ALLOW 2>&1 | tee -a $LOG_FILE
  else
    echo "ALL:${current_ip}" >>$HOSTS_ALLOW 2>&1 | tee -a $LOG_FILE
  fi
}

# Check if a ufw rule exists, returns the rule no
check_if_rule_exists() {
  local user_ip=$1
  local port=$2
  local proto=$3 # unused for now
  local ufw_rule_num=$(${UFW} status numbered | grep "${user_ip}" | grep " ${port}[ /]" | awk -F'ALLOW IN' '{gsub(/^\[| /, ""); gsub(/\].*/, ""); print $1}')
  if [ "$ufw_rule_num" ]; then
    echo "$ufw_rule_num"
  else
    echo 0
  fi
}

add_ufw_rule() {
  local current_ip=$1
  local port=$2
  local proto=$3
  local exists=$(check_if_rule_exists "$current_ip" "$port" "$proto")
  if [ "$exists" != 0 ]; then
    echo "$(timestamp) [Info] IP ${current_ip} hasn't changed, leaving it alone... If it ain't brok'n, dont't fix it !" 2>&1 | tee -a $LOG_FILE
  else
    echo "$(timestamp) [Info] IP ${current_ip} for ${FQDN} has changed. Updating FW script with ${current_ip}..." 2>&1 | tee -a $LOG_FILE
    ${UFW} allow proto "${proto}" from "${current_ip} "to any port "${port}" comment "${FQDN} - $(timestamp)" 2>&1 | tee -a $LOG_FILE
  fi
}

delete_ufw_rule() {
  local old_ip=$1
  local port=$2
  local proto=$3
  exists=$(check_if_rule_exists "$old_ip" "$port" "$proto")
  if [ "$exists" != 0 ]; then
    echo "$(timestamp) [Info] Deleting rule for old IP ${old_ip}..." 2>&1 | tee -a $LOG_FILE
    ${UFW} delete allow proto "${proto}" from "${old_ip}" to any port "${port}" 2>&1 | tee -a $LOG_FILE
  else
    echo "$(timestamp) [Info] No rule found for the old IP ${old_ip}, nothing deleted...!" 2>&1 | tee -a $LOG_FILE
  fi
}

if [ "$1" ] && [ "$2" ] && [ "$3" ]; then
  FQDN="$1"
  PORT="$2"
  PROTO="$3"
  IP_FILE="${IP_FILE_PATH}${FQDN}.${IP_FILE_SFX}"
  OLD_IP=''
  CURRENT_IP=$(nslookup "${FQDN}" | grep -Po '[^\t]\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b' | awk '{print $1}')
  if [ ! "$CURRENT_IP" ]; then
    echo "$(timestamp) [Error] no IP could be retrieved. Exiting script..." 2>&1 | tee -a $LOG_FILE
    exit
  fi
  if [ -f "$IP_FILE" ]; then
    echo "$(timestamp) [Info] Using previously saved IP state file '${IP_FILE}'" 2>&1 | tee -a $LOG_FILE
    OLD_IP=$(grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' "$IP_FILE")
  else
    echo "$(timestamp) [Info] No previous IP file could be found, creating a new one now at '${IP_FILE}'" 2>&1 | tee -a $LOG_FILE
  fi
  echo "${CURRENT_IP}" >"$IP_FILE" 2>&1 | tee -a $LOG_FILE

  exists=$(check_if_rule_exists "$CURRENT_IP" "$PORT" "$PROTO")
  if [ "$OLD_IP" = "$CURRENT_IP" ] && [ "$exists" != 0 ]; then
    echo "$(timestamp) [Info] IP ${CURRENT_IP} hasn't changed. Terminating script..." 2>&1 | tee -a $LOG_FILE
    exit
  else
    delete_ufw_rule "$OLD_IP" "$PORT" "$PROTO"
    add_ufw_rule "$CURRENT_IP" "$PORT" "$PROTO"
    update_hosts_file "$CURRENT_IP" "$OLD_IP"
  fi
else
  echo "$(timestamp) [Syntax] Expected : ipcheck.script fqdn port protocol" 2>&1 | tee $LOG_FILE
  echo "$(timestamp) [Syntax] Got      : ipcheck.script ${0}" 2>&1 | tee -a $LOG_FILE
  echo "$(timestamp) [Syntax] Example  : ipcheck.script my.dns.ch 22 tcp" 2>&1 | tee -a $LOG_FILE
fi
