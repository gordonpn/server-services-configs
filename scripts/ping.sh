#!/bin/bash
set -o allexport
source /home/gordonpn/workspace/server-services-configs/scripts/.env
set +o allexport

curl -vs --retry 3 https://hc-ping.com/"$PING_HC_UUID"/start
echo

unameOut="$(uname -s)"
case "${unameOut}" in
Linux*) machine=Linux ;;
Darwin*) machine=Mac ;;
*) machine="UNKNOWN:${unameOut}" ;;
esac

if [[ "$machine" == "Linux" ]]; then
  logfile="/home/gordonpn/logs/ping.log"
elif [[ "$machine" == "Mac" ]]; then
  logfile="/Users/gordonpn/logs/ping.log"
else
  echo "OS unsupported, exiting..."
  exit 1
fi

ips=(
  8.8.8.8
  8.8.4.4
  1.1.1.1
  192.168.1.65
  192.168.1.146
)
len=${#ips[@]}
threshold=$((2 * 2 * len))
logfile_threshold=$((3 * threshold))

ping_and_log() {
  for ip in "${ips[@]}"; do
    if ping -W 1 -c 3 "$ip" >/dev/null 2>&1; then
      echo "$ip is up"
      echo "up" >>"${logfile}"
    else
      echo "$ip is down"
      echo "down" >>"${logfile}"
    fi
  done
}

shutdown_machine() {
  echo "Too many ping failures detected, shutting down..."
  if [[ "$machine" == "Linux" ]]; then
    /usr/sbin/shutdown --poweroff 10
  fi
  exit
}

check_log() {
  local lines
  lines=$(wc -l <${logfile})
  local count=0
  echo "$logfile has $lines lines."
  if ((lines > threshold)); then
    while read -r p; do
      if [[ "$p" == "up" ]]; then
        count=0
      else
        ((count = count + 1))
      fi
    done <${logfile}
    echo "$count down in a row"
  fi

  echo "Threshold is set at ${threshold}"
  if ((count >= threshold)); then
    shutdown_machine
  fi
}

clean_log() {
  local lines
  lines=$(wc -l <${logfile})
  if ((lines >= logfile_threshold)); then
    lines_to_remove=$((len + 1))
    echo "Trimming first ${len} lines from log file."
    tail -n +"${lines_to_remove}" "$logfile" >"$logfile.tmp" && mv "$logfile.tmp" "$logfile"
  else
    echo "Log file not long enough yet, not trimming."
  fi
}

delete_log() {
  echo "Deleting current log..."
  rm "$logfile"
}

if [ -f "$logfile" ]; then
  check_log
fi

ping_and_log
clean_log

curl -vs --retry 3 https://hc-ping.com/"$PING_HC_UUID"
echo
