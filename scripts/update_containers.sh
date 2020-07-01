#!/usr/bin/env bash
set -o allexport; source /home/gordonpn/workspace/container/scripts/.env; set +o allexport

curl --retry 3 https://hc-ping.com/"$UPDATE_HC_UUID"/start
echo

base_path="/home/gordonpn/workspace/container"
container_dirs=(
	"drone"
	"droppy"
	"resilio-sync"
	"traefik"
	"swarmpit"
)

for dir in "${container_dirs[@]}"
do
	cd "$base_path"/"$dir" || break
	./deploy.sh
done

curl --retry 3 https://hc-ping.com/"$UPDATE_HC_UUID"
echo
