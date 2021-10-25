#!/bin/bash

HOSTS_RULES=/etc/ufw-dynamic-hosts.allow
HOSTS_ALLOW=/etc/hosts.allow
IPS_ALLOW=/var/tmp/ufw-dynamic-ips.allow
UFW=/usr/sbin/ufw

timestamp=$(date +"%Y-%m-%d %T")

add_rule() {
  local proto=$1
  local port=$2
  local ip=$3
  local comment="$4"
  local regex="${port}\/${proto}.*ALLOW.*IN.*${ip}"
  local rule=$(${UFW} status numbered | grep "$regex")
  # echo "Comment: ${comment}"
  if [ -z "$rule" ]; then
    ${UFW} allow proto "${proto}" from "${ip}" to any port "${port}" comment "${comment} - ${timestamp}"
    echo "${timestamp} [Info] rule does not exist. Added ${proto} from ${ip} to any ${port} for ${comment}"
  else
    echo "${timestamp} [Info] rule already exists for IP:${ip}, nothing to do."
  fi
}

delete_rule() {
  local proto=$1
  local port=$2
  local ip=$3
  local regex="${port}\/${proto}.*ALLOW.*IN.*${ip}"
  local rule=$(${UFW} status numbered | grep "$regex")
  if [ -n "$rule" ]; then
    ${UFW} delete allow proto "${proto}" from "${ip}" to any port "${port}"
    echo "${timestamp} [Info] rule deleted ${proto} from ${ip} to any port ${port}"
  else
    echo "${timestamp} [Info] rule for IP:${ip} does not exist. nothing to delete."
  fi
}

update_hosts_file() {
  local current_ip=$1
  local old_ip=$2
  local comment="$3"
  local rule_exists=""
  if [ -n "${current_ip}" ]; then
    if [ -n "${old_ip}" ] && [ "${old_ip}" != "${current_ip}" ]; then
      rule_exists=$(grep -o "^ALL:${old_ip}" $HOSTS_ALLOW)
      if [ -n "$rule_exists" ]; then
        echo "${timestamp} [Info] Delete old rules with IP:${old_ip} from <hosts.allow>..."
        sed -i.bak "/${old_ip}/d" ${HOSTS_ALLOW}
      fi
    fi
    rule_exists=$(grep -o "^ALL:${current_ip}" $HOSTS_ALLOW)
    if [ -n "$rule_exists" ]; then
      echo "${timestamp} [Info] Nothing has changed, leaving hosts.allow as-is."
    else
      echo "${timestamp} [Info] Adding IP ${current_ip} to <hosts.allow>..."
      echo "## Rule for ${comment} IP:${current_ip}, updated on ${timestamp}" >>$HOSTS_ALLOW
      echo "ALL:${current_ip}" >>$HOSTS_ALLOW
    fi
  fi
}

sed '/^[[:space:]]*$/d' ${HOSTS_RULES} | sed '/^[[:space:]]*#/d' | while read -r line; do
  proto=$(echo "${line}" | cut -d: -f1)
  port=$(echo "${line}" | cut -d: -f2)
  host=$(echo "${line}" | cut -d: -f3)
  comment=$(echo "${line}" | cut -d: -f4)

  if [ -f ${IPS_ALLOW} ]; then
    old_ip=$(cat "${IPS_ALLOW}" | grep "${host}" | cut -d: -f2)
  fi
  ip=$(dig +short "$host" | tail -n 1)

  if [ -z "${ip}" ]; then
    if [ -n "${old_ip}" ]; then
      delete_rule "${proto}" "${port}" "${old_ip}"
      # echo "${timestamp} ${proto} ${port} ${old_ip} removed"
    fi
    echo "${timestamp} [Warning] Failed to resolve the ip address of ${host}." 1>&2
    exit 1
  fi

  if [ -n "${old_ip}" ]; then
    if [ "${ip}" != "${old_ip}" ]; then
      delete_rule "${proto}" "${port}" "${old_ip}"
    fi
  fi

  add_rule "${proto}" "${port}" "${ip}" "${comment} (${host})"
  update_hosts_file "${ip}" "${old_ip}" "${comment} (${host})"

  if [ -f ${IPS_ALLOW} ]; then
    sed -i.bak "/^${host}*/d" ${IPS_ALLOW}
  fi
  echo "${host}:${ip}" >>${IPS_ALLOW}
done
