#!/usr/bin/env bash

# the following is not posix compatible, but the next is
scripts_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
# scripts_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if [ "$JENKINS_CI" = "true" ] || [ "$DRONE_CI" = "true" ]; then
	inside_docker="true"
else
	inside_docker="false"
fi

if [ "$inside_docker" == "true" ]; then
	echo 'Running inside a Docker container'
else
	set -o allexport
	# shellcheck disable=SC1091
	source "$scripts_dir"/.env || exit 1
	set +o allexport
	# shellcheck disable=SC1091
	source "$scripts_dir"/trim_logs.sh
fi

curl -s --retry 3 https://hc-ping.com/"$UPDATE_HC_UUID"/start
echo

services=(
	"adguard"
	"drone"
	"jellyfin"
	"jenkins"
	"portainer"
	"traefik"
	# "filebrowser"
	# "swarmpit"
	# "syncthing"
	# "transmission-openvpn"
)

for service in "${services[@]}"; do
	printf "\n=========== START: %s =========== SERVICE: %s\n" "$(date +%F_%T)" "$service"
	cd "$scripts_dir"/../"$service"/ || break
	if [ "$JENKINS_CI" == "true" ]; then
		docker compose convert >|docker-compose.processed.yml || exit 1
	elif [ "$DRONE_CI" == "true" ]; then
		docker-compose -f docker-compose.yml config >|docker-compose.processed.yml || exit 1
	else
		/usr/local/bin/docker-compose -f docker-compose.yml config >|docker-compose.processed.yml || exit 1
	fi
	echo -e "version: \"3.9\"\n$(cat docker-compose.processed.yml)" >|docker-compose.processed.yml
	if [ "$inside_docker" == "true" ]; then
		docker stack deploy -c docker-compose.processed.yml "$service" || exit 1
	else
		/usr/bin/docker stack deploy -c docker-compose.processed.yml "$service" || exit 1
	fi
	printf "\n=========== END : %s ==========================\n" "$(date +%F_%T)"
done

curl -s --retry 3 https://hc-ping.com/"$UPDATE_HC_UUID"
echo

if [ "$inside_docker" == "false" ]; then
	trim_logs "/media/drive/logs/deploy.log"
fi
