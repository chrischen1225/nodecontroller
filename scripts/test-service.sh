#!/bin/bash

# Determine root and alternate boot medium root device paths
. /usr/lib/waggle/core/scripts/detect_disk_devices.sh

wait_for_gn_reboot() {
  local rebooting=0
  while [ $rebooting -eq 0 ]; do
    last_hb=$(wagman-client hb | sed -n '2p')
    if [ $last_hb -gt 10000 ]; then
      rebooting=1
    fi
  done

  while [[ $rebooting -eq 1 ]]; do
    last_hb=$(wagman-client hb | sed -n '2p')
    if [ $last_hb -lt 10000 ]; then
      # reboot succeeded
      rebooting=0
    elif [ $last_hb -gt 70000 ]; then
      # reboot failed
      return 1
    fi
  done
}

run_gn_tests() {
  # Run tests on the SD or eMMC
  ssh -i /usr/lib/waggle/SSL/guest/id_rsa_waggle_aot_guest_node waggle@10.31.81.51 \
    -o "StrictHostKeyChecking no" -o "PasswordAuthentication no" -o "ConnectTimeout 2" \
    /usr/lib/waggle/guestnode/scripts/run_tests.sh

  # Reboot to the alternate disk medium to continue the test cycle
  local current_gn_device_type=$(wagman-client bs 1)
  local other_gn_device_type=''
  if [ "${current_gn_device_type}" == "sd" ]; then
    other_gn_device_type='emmc'
  fi
  wagman-client bs 1 $other_gn_device_type
  wagman-client stop 1 0
  wait_for_gn_reboot

  # Run tests on the eMMC or SD
  ssh -i /usr/lib/waggle/SSL/guest/id_rsa_waggle_aot_guest_node waggle@10.31.81.51 \
    -o "StrictHostKeyChecking no" -o "PasswordAuthentication no" -o "ConnectTimeout 2" \
    /usr/lib/waggle/guestnode/scripts/run_tests.sh

  # Reboot to SD if we started the GN test cycle on the eMMC
  if [ "$current_gn_device_type" == "sd" ]; then
    wagman-client bs 1 $current_gn_device_type
    wagman-client stop 1 0
    wait_for_gn_reboot

    # Finish tests on the SD
    ssh -i /usr/lib/waggle/SSL/guest/id_rsa_waggle_aot_guest_node waggle@10.31.81.51 \
      -o "StrictHostKeyChecking no" -o "PasswordAuthentication no" -o "ConnectTimeout 2" \
      /usr/lib/waggle/guestnode/scripts/run_tests.sh
  fi
}

run_tests() {
  if [ "${CURRENT_DISK_DEVICE_TYPE}" == "SD" ]; then
    run_gn_tests
  fi
  /usr/lib/waggle/nodecontroller/scripts/test_node.sh \
    > /home/waggle/test_node_NC_${CURRENT_DISK_DEVICE_TYPE}.log
}

generate_report() {
  local report_file="/home/waggle/test-report.txt"
  echo "Node Controller SD Test Results" >> $report_file
  echo "-------------------------------" >> $report_file
  cat /home/waggle/test_node_NC_SD.log >> $report_file

  echo >> $report_file
  echo "Node Controller eMMC Test Results" >> $report_file
  echo "---------------------------------" >> $report_file
  cat /media/test/home/waggle/test_node_NC_MMC.log >> $report_file

  echo >> $report_file
  echo >> $report_file
  echo "########################################" >> $report_file
  echo "Guest Node Test Results Should Follow..." >> $report_file
  echo "########################################" >> $report_file
  echo >> $report_file

  echo >> $report_file
  cat /home/waggle/gn-test-report.txt >> $report_file
  ssh -i /usr/lib/waggle/SSL/guest/id_rsa_waggle_aot_guest_node waggle@10.31.81.51 \
    -o "StrictHostKeyChecking no" -o "PasswordAuthentication no" -o "ConnectTimeout 2" \
    cat /home/waggle/test-report.txt >> $report_file
}

mount | grep '/media/test' && true
if [ $? -eq 1 ]; then
  mount "${OTHER_DISK_DEVICE}p2" /media/test
fi

start_file=/home/waggle/start_test
continue_file=/home/waggle/continue_test
finish_file=/home/waggle/finish_test
if [ -e ${start_file} ] ; then
  run_tests
  if [ "${CURRENT_DISK_DEVICE_TYPE}" == "SD" ]; then
    wagman-client bs 0 emmc
  else
    wagman-client bs 0 sd
  fi
  touch /media/test${continue_file}
  rm ${start_file}
  wagman-client stop 0 0
elif [ -e ${continue_file} ]; then
  run_tests
  if [ "${CURRENT_DISK_DEVICE_TYPE}" == "MMC" ]; then
    touch /media/test${finish_file}
  elif [ "${CURRENT_DISK_DEVICE_TYPE}" == "SD" ]; then
    generate_report
  fi
  rm ${continue_file}
  wagman-client bs 0 sd
  wagman-client stop 0 0
elif [ -e ${finish_file} ]; then
  generate_report
  rm ${finish_file}
fi