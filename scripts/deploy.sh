#!/usr/bin/env bash

scripts_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

if [ "$INSIDE_DOCKER" != "true" ]; then
	set -o allexport
	source "$scripts_dir"/.env || exit 1
	set +o allexport
	source "$scripts_dir"/trim_logs.sh
	docker_compose_command() {
		/usr/local/bin/docker-compose "$1"
	}
	docker_command() {
		/usr/bin/docker "$1"
	}
else
	echo 'Running inside a Docker container'
	docker_compose_command() {
		docker compose "$1"
	}
	docker_command() {
		docker "$1"
	}
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
	docker_compose_command "-f docker-compose.yml config >docker-compose.processed.yml"
	echo -e "version: \"3.8\"\n$(cat docker-compose.processed.yml)" >docker-compose.processed.yml
	docker_command "stack deploy -c docker-compose.processed.yml ""$service"""
	printf "\n=========== END : %s ==========================\n" "$(date +%F_%T)"
done

curl -s --retry 3 https://hc-ping.com/"$UPDATE_HC_UUID"
echo

if [ "$INSIDE_DOCKER" != "true" ]; then
	trim_logs "/media/drive/logs/deploy.log"
fi
