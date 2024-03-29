#!/bin/bash
set -o allexport
source /home/gordonpn/workspace/server-services-configs/scripts/.env
set +o allexport

curl -s --retry 3 https://hc-ping.com/"$REBALANCE_HC_UUID"/start
echo

logfile="/home/gordonpn/logs/force_rebalance.log"

clean_log() {
  local lines
  lines=$(wc -l <${logfile})
  if ((lines >= 80)); then
    lines_to_remove=$((lines - 80 + 1))
    tail -n +"${lines_to_remove}" "$logfile" >"$logfile.tmp" && mv "$logfile.tmp" "$logfile"
  else
    echo "Log file not long enough yet, not trimming."
  fi
}

abs() {
  [[ $(($@)) -lt 0 ]] && echo "$((($@) * -1))" || echo "$(($@))"
}

mapfile -t pi_tasks < <(/usr/bin/docker node ps --filter desired-state=running gordonpn-pi --format "{{.Name}}")
mapfile -t server_tasks < <(/usr/bin/docker node ps --filter desired-state=running gordonpn-server --format "{{.Name}}")

pi_availability=$(/usr/bin/docker node inspect gordonpn-pi --format "{{ .Spec.Availability }}")
server_availability=$(/usr/bin/docker node inspect gordonpn-server --format "{{ .Spec.Availability }}")
pi_state=$(/usr/bin/docker node inspect gordonpn-pi --format "{{ .Status.State }}")
server_state=$(/usr/bin/docker node inspect gordonpn-server --format "{{ .Status.State }}")

num_server_tasks=${#server_tasks[@]}
num_pi_tasks=${#pi_tasks[@]}
total_tasks=$((num_server_tasks + num_pi_tasks))
difference=$(abs "$num_server_tasks" - "$num_pi_tasks")

printf '%s\n' "$(date)"
printf 'total tasks running: %d\n' "$total_tasks"
printf '%d tasks running on the server\n' "$num_server_tasks"
printf '%d tasks running on the pi\n' "$num_pi_tasks"
printf 'difference of tasks: %d\n' "$difference"

if [ "$pi_availability" == "active" ] && [ "$server_availability" == "active" ] && [ "$pi_state" == "ready" ] && [ "$server_state" == "ready" ]; then
  if [ "$difference" -gt $((total_tasks / 2)) ]; then
    printf 'rotating certificates...\n'
    /usr/bin/docker swarm ca --rotate --quiet
    sleep 10

    mapfile -t services_array < <(/usr/bin/docker service ls --format "{{.Name}}")

    for service in "${services_array[@]}"; do
      if [ "$service" == "traefik_traefik" ]; then
        continue
      fi
      printf 'force rebalancing service: %s\n' "$service"
      /usr/bin/docker service update --force --quiet "$service" &
      sleep 2
    done

  else
    printf 'not rebalancing\n'
  fi
else
  printf 'either Raspberry Pi or Server not available'
  printf 'nothing performed'
fi

clean_log

curl -s --retry 3 https://hc-ping.com/"$REBALANCE_HC_UUID"
echo
printf 'done\n'
