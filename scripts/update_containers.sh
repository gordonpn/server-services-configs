#!/usr/bin/env bash
# set -x
set -o allexport; source /home/gordonpn/workspace/container/scripts/.env; set +o allexport

curl --retry 3 https://hc-ping.com/"$UPDATE_HC_UUID"/start
echo

base_path="/home/gordonpn/workspace/container"
container_dirs=(
	"dozzle"
	"drone"
	"droppy"
	"resilio-sync"
	"slack-docker"
	"traefik"
)

for dir in "${container_dirs[@]}"
do
	cd "$base_path"/"$dir" || break
	/usr/local/bin/docker-compose pull
	/usr/local/bin/docker-compose up --remove-orphans --detach
done

curl --retry 3 https://hc-ping.com/"$UPDATE_HC_UUID"
echo
