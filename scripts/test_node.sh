#!/bin/bash

set +e

print_result() {
  local test_description=$1
  local result=$2
  local optional=$3
  local software=$4
  local pretext=""
  local posttext=""
  if [ $result == 0 ]; then
    if [[ ! -z ${software+x} && $software == 1 ]]; then
      echo "[0;30;32m[PASS][0;30;37m [0;30;34m${test_description}[0;30;37m"
    else
      echo "[0;30;32m[PASS][0;30;37m ${test_description}"
    fi
  elif [[ ! -z ${optional+x} && $optional == 1 ]]; then
    if [[ ! -z ${software+x} && $software == 1 ]]; then
      echo "[0;30;33m[FAIL][0;30;37m [0;30;34m${test_description}[0;30;37m"
    else
      echo "[0;30;33m[FAIL][0;30;37m ${test_description}"
    fi
  else
    if [[ ! -z ${software+x} && $software == 1 ]]; then
      echo "[0;30;31m[FAIL][0;30;37m [0;30;34m${test_description}[0;30;37m"
    else
      echo "[0;30;31m[FAIL][0;30;37m ${test_description}"
    fi
  fi
}

shadow='root:$6$D3j0Te22$md6NULvJPliwvAhK2BlL96XCsJ0KdTnPqNdufDWgyU5k6Nc3M88qO64WCKKTLZry1GgKhGE95L5ZA1i2VFQGn.:17079:0:99999:7:::'
fgrep $shadow /etc/shadow
print_result "AoT Root Password Set" $? 0 1

keys=('ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCsYPMSrC6k33vqzulXSx8141ThfNKXiyFxwNxnudLCa0NuE1SZTMad2ottHIgA9ZawcSWOVkAlwkvufh4gjA8LVZYAVGYHHfU/+MyxhK0InI8+FHOPKAnpno1wsTRxU92xYAYIwAz0tFmhhIgnraBfkJAVKrdezE/9P6EmtKCiJs9At8FjpQPUamuXOy9/yyFOxb8DuDfYepr1M0u1vn8nTGjXUrj7BZ45VJq33nNIVu8ScEdCN1b6PlCzLVylRWnt8+A99VHwtVwt2vHmCZhMJa3XE7GqoFocpp8TxbxsnzSuEGMs3QzwR9vHZT9ICq6O8C1YOG6JSxuXupUUrHgd AoT_key' \
      'command="/bin/date" ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCedz4oU6YdvFjbWiJTpJiREplTizAk2s2dH0/aBMLmslSXzMXCgAh0EZOjsA3CW+P2SIn3NY8Hx3DmMR9+a1ISd3OcBcH/5F48pejK1MBtdLOnai64JmI80exT3CR34m3wXpmFbbzQ5jrtGFb63q/n89iVDb+BwY4ctrBn+J7BPEJbhh/aepoUNSG5yICWtjC0q8mDhHzr+40rYsxPXjp9HTaEzgLu+fNhJ0rK+4891Lr08MTud2n8TEntjBRlWQUciGrPn1w3jzIz+q2JdJ35a/MgLg6aRSQOMg6AdanZH2XBTqHbaeYOWrMhmDTjC/Pw9Jczl7S+wr0648bzXz2T AoT_key_test' \
      'from="10.31.81.5?" ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC4ohQv1Qksg2sLIqpvjJuZEsIkeLfbPusEaJQerRCqI71g8hwBkED3BBv5FehLcezTg+cFJFhf2vBGV5SbV0NzbouIM+n0lAr6+Ei/XYjO0B1juDm6cUmloD4HSzQWv+cSyNmb7aXjup7V0GP1DZH3zlmvwguhMUTDrWxQxDpoV28m72aZ4qPH7VmQIeN/JG3BF9b9F8P4myOPGuk5XTjY1rVG+1Tm2mxw0L3WuL6w3DsiUrvlXsGE72KcyFBDiFqOHIdnIYWXDLZz61KXctVLPVLMevwU0YyWg70F9pb0d2LZt7Ztp9GxXBRj5WnU9IClaRh58RsYGhPjdfGuoC3P AoT_guest_node_key')
echo ${keys[@]}
key_names=('AoT Key' 'AoT Test Key' 'AoT Guest Key')
for i in $(seq 0 `expr ${#keys[@]} - 1`); do
  key=${keys[i]}
  key_name=${key_names[i]}
  fgrep "$key" /home/waggle/.ssh/authorized_keys
  print_result "$key_name Auth" $? 0 1
done

grep '^sudo:x:27:$' /etc/group
print_result "sudo Disabled" $? 0 1

directories=("/etc/waggle" "/usr/lib/waggle" "/usr/lib/waggle/core" "/usr/lib/waggle/plugin_manager" "/usr/lib/waggle/nodecontroller" \
             "/usr/lib/waggle/SSL" "/usr/lib/waggle/SSL/guest" "/usr/lib/waggle/SSL/node" "/usr/lib/waggle/SSL/waggleca")
for dir in ${directories[@]}; do
  [ -e $dir ]
  print_result "$dir Directory" $? 0 1
done

perms=$(stat -c '%U %G %a' /usr/lib/waggle/SSL/guest/id_rsa_waggle_aot_guest_node)
[ "$perms" == "root root 600" ]
print_result "Guest Key Permissions" $? 0 1

perms=$(stat -c '%U %G %a' /usr/lib/waggle/SSL/node/key.pem)
[ "$perms" == "rabbitmq rabbitmq 600" ]
print_result "Node Key Permissions" $? 0 1

perms=$(stat -c '%U %G %a' /usr/lib/waggle/SSL/node/cert.pem)
[ "$perms" == "rabbitmq rabbitmq 600" ]
print_result "Node Key Permissions" $? 0 1

perms=$(stat -c '%U %G %a' /usr/lib/waggle/SSL/waggleca/cacert.pem)
[ "$perms" == "root root 644" ]
print_result "Waggle CA Cert Permissions" $? 0 1

# Ethernet IP Address (NC)
ifconfig | fgrep "          inet addr:10.31.81.10  Bcast:10.31.81.255  Mask:255.255.255.0" && true
print_result "Built-in Ethernet IP Address" $? 0 0

devices=("waggle_sysmon" "waggle_coresense")
device_names=("WagMan" "Coresense")
for i in $(seq 0 `expr ${#devices[@]} - 1`); do
  device=${devices[i]}
  device_name=${device_names[i]}
  [ -e /dev/$device ]
  print_result "$device_name Device" $? 0 0
done

devices=("alphasense" "gps_module" "attwwan")
device_names=("Alphasense" "GPS" "Modem")
for i in $(seq 0 `expr ${#devices[@]} - 1`); do
  device=${devices[i]}
  device_name=${device_names[i]}
  [ -e /dev/$device ]
  print_result "Optional $device_name Device" $? 1 0
done

lsusb | grep 1bc7:0021 && true
if [ $? -eq 0 ]; then
  # Found USB Modem Device
  print_result "Modem USB" 0 0 0

  ifconfig | grep ppp0 -A 1 | fgrep "inet addr:" && true
  print_result "Modem IP Address" $? 0 0
else
  # No USB Modem Device Present
  ifconfig | grep -A 1 enx | grep 'inet addr:' && true
  exit_code=$?
  if [ $exit_code -ne 0 ]; then
    # give networking another try after a brief rest
    sleep 10
    ifconfig | grep -A 1 enx | grep 'inet addr:' && true
    exit_code=$?
  fi
  print_result "USB Ethernet IP Address" $exit_code 0 0
fi

line_count=$(cat /etc/ssh/sshd_config | fgrep -e 'ListenAddress 127.0.0.1' -e 'ListenAddress 10.31.81.10' | wc -l)
[ $line_count -eq 2 ]
print_result "sshd Listen Addresses" $? 0 1

cat /etc/waggle/node_id | egrep '[0-9a-f]{16}' && true
print_result "Node ID Set" $? 0 1

. /usr/lib/waggle/core/scripts/detect_mac_address.sh
cat /etc/hostname | fgrep "${MAC_STRING}${CURRENT_DISK_DEVICE_TYPE}" && true
print_result "Hostname Set" $? 0 1

. /usr/lib/waggle/core/scripts/detect_disk_devices.sh
parted -s ${CURRENT_DISK_DEVICE}p2 print | grep --color=never -e ext | awk '{print $3}' | egrep '15\.[0-9]GB' && true
print_result "SD Resize" $? 0 0

parted -s ${OTHER_DISK_DEVICE}p2 print | grep --color=never -e ext | awk '{print $3}' | egrep '15\.[0-9]GB' && true
print_result "Recovery to eMMC" $? 0 0

units=("waggle-communications" "waggle-epoch" "waggle-heartbeat" \
       "waggle-monitor-connectivity" "waggle-monitor-shutdown" \
       "waggle-monitor-system" "waggle-monitor-wagman" \
       "waggle-wagman-publisher" "waggle-wagman-server")
for unit in ${units[@]}; do
  systemctl status $unit | fgrep 'Active: active (running)' && true
  exit_code=$?
  if [ $exit_code -ne 0 ]; then
    # give systemctl status another try after a brief rest
    sleep 5
    systemctl status $unit | fgrep 'Active: active (running)' && true
    exit_code=$?
  fi
  print_result "$unit Service" $? 0 1
done

units=("waggle-wwan" "waggle-reverse-tunnel")
for unit in ${units[@]}; do
  systemctl status $unit | fgrep -e 'Active: active (running)' -e 'Active: activating (auto-restart)' && true
  exit_code=$?
  if [ $exit_code -ne 0 ]; then
    # give systemctl status another try after a brief rest
    sleep 5
    systemctl status $unit | fgrep -e 'Active: active (running)' -e 'Active: activating (auto-restart)' && true
    exit_code=$?
  fi
  print_result "$unit Service" $exit_code 0 1
done

# ssh to GN
ssh -i /usr/lib/waggle/SSL/guest/id_rsa_waggle_aot_guest_node waggle@10.31.81.51 \
    -o "StrictHostKeyChecking no" -o "PasswordAuthentication no" -o "ConnectTimeout 2" /bin/date
print_result "ssh to GN" $? 0 0
