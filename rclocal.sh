#!/bin/bash

CONFIG_FILE="/root/config.txt"
source $CONFIG_FILE

for i in {1..5}; do bash /root/utils/update_status.sh; sleep 10; done >/dev/null 2>&1 &
rm -f /home/miner/.cache/sessions/*
rm -f /etc/udev/rules.d/70-persistent-net.rules
rm -f /etc/X11/xorg*

##bash /root/utils/update_version.sh
bash /root/utils/rdate.sh
if [ $osSeries == "R" ]; then
  aticonfig --initial --adapter=all &
  su miner -c 'bash /root/utils/run_in_screen.sh srr_pre /root/utils/SRR/keepalive.sh' &
fi
if [ $osSeries == "RX" ]; then
  sudo /root/utils/oc_save_pp_table.sh
  su miner -c 'bash /root/start.sh' &
fi
if [ $osSeries == "NV" ]; then
  re='3D controller: NVIDIA'
  nvidia-xconfig -a --allow-empty-initial-configuration --cool-bits=31 --use-display-device="DFP-0" --connected-monitor="DFP-0"
  if [[ `lspci` =~ $re  ]]; then
    export DISPLAY=:0.0
    X :0 &
    xhost +
  else
    startx & # -display :2 -- :2 vt2 &
  fi
  sleep 6
  sudo cp /.Xauthority /home/miner
  if [[ `lspci` =~ $re  ]]; then
    export DISPLAY=:0.0
  fi
  chvt 1 &
  su miner -c 'bash /root/start.sh' &
  sleep 5 ; chvt 1 &
  sleep 10 ; chvt 1 &
  sleep 30 ; chvt 1 &
fi
