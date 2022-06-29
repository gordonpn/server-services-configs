#!/usr/bin/env bash

scripts_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

if [ "$INSIDE_DOCKER" != "true" ]; then
	set -o allexport
	source "$scripts_dir"/.env || exit 1
	set +o allexport
	source "$scripts_dir"/trim_logs.sh
else
	echo 'Running inside a Docker container'
fi

curl -s --retry 3 https://hc-ping.com/"$UPDATE_HC_UUID"/start
echo

services=(
	"adguard"
	"drone"
	"jellyfin"
	"jenkins"
	"swarmpit"
	"syncthing"
	"traefik"
	"transmission-openvpn"
	# "filebrowser"
)

for service in "${services[@]}"; do
	printf "\n=========== START: %s =========== SERVICE: %s\n" "$(date +%F_%T)" "$service"
	cd "$scripts_dir"/../"$service"/ || break
	if [ "$INSIDE_DOCKER" == "true" ]; then
		docker compose convert >|docker-compose.processed.yml
	else
		/usr/local/bin/docker-compose -f docker-compose.yml config >|docker-compose.processed.yml
	fi
	echo -e "version: \"3.9\"\n$(cat docker-compose.processed.yml)" >|docker-compose.processed.yml
	if [ "$INSIDE_DOCKER" == "true" ]; then
		docker stack deploy -c docker-compose.processed.yml "$service"
	else
		/usr/bin/docker stack deploy -c docker-compose.processed.yml "$service"
	fi
	printf "\n=========== END : %s ==========================\n" "$(date +%F_%T)"
done

curl -s --retry 3 https://hc-ping.com/"$UPDATE_HC_UUID"
echo

if [ "$INSIDE_DOCKER" != "true" ]; then
	trim_logs "/media/drive/logs/deploy.log"
fi
