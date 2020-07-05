#!/bin/bash
set -o allexport; source /home/gordonpn/workspace/container/scripts/.env; set +o allexport

curl --retry 3 https://hc-ping.com/"$REBALANCE_HC_UUID"/start
echo

logfile="/home/gordonpn/logs/force_rebalance.log"

clean_log() {
	local lines
	lines=$(wc -l <${logfile})
	if ((lines >= 80)); then
		lines_to_remove=$((lines - 80 + 1))
		tail -n +"${lines_to_remove}" "$logfile" > "$logfile.tmp" && mv "$logfile.tmp" "$logfile"
	else
		echo "Log file not long enough yet, not trimming."
	fi
}

abs() {
    [[ $(( $@ )) -lt 0 ]] && echo "$(( ($@) * -1 ))" || echo "$(( $@ ))"
}

mapfile -t server_tasks < <( /usr/bin/docker node ps --filter desired-state=running gordonpn-pi --format "{{.Name}}" )
mapfile -t pi_tasks < <( /usr/bin/docker node ps --filter desired-state=running gordonpn-server --format "{{.Name}}" )

num_server_tasks=${#server_tasks[@]}
num_pi_tasks=${#pi_tasks[@]}
total_tasks=$(( num_server_tasks + num_pi_tasks ))
difference=$(abs "$num_server_tasks" - "$num_pi_tasks")

printf 'total tasks running: %d\n' "$total_tasks"
printf '%d tasks running on the server\n' "$num_server_tasks"
printf '%d tasks running on the pi\n' "$num_pi_tasks"
printf 'difference: %d\n' "$difference"

if [ "$difference" -gt $(( total_tasks / 2 )) ]; then
	printf 'rotating certificates...\n'
	/usr/bin/docker swarm ca --rotate --quiet
	sleep 10

	mapfile -t services_array < <( /usr/bin/docker service ls --format "{{.Name}}" )

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

clean_log

curl --retry 3 https://hc-ping.com/"$REBALANCE_HC_UUID"
echo
printf 'done\n'
