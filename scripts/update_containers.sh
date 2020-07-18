#!/usr/bin/env bash
set -o allexport; source /home/gordonpn/workspace/container/scripts/.env; set +o allexport

curl --retry 3 https://hc-ping.com/"$UPDATE_HC_UUID"/start
echo

logfile="/home/gordonpn/logs/container_update.log"

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

base_path="/home/gordonpn/workspace/container"
container_dirs=(
	"drone"
	"filebrowser"
	"portainer"
	"resilio-sync"
	"traefik"
)

for dir in "${container_dirs[@]}"
do
	cd "$base_path"/"$dir" || break
	./deploy.sh
done

clean_log

curl --retry 3 https://hc-ping.com/"$UPDATE_HC_UUID"
echo
