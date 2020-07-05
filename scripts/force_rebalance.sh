#!/bin/bash

mapfile -t services_array < <( /usr/bin/docker service ls --format "{{.Name}}" )
mapfile -t server_tasks < <( /usr/bin/docker node ps --filter desired-state=running gordonpn-pi --format "{{.Name}}" )
mapfile -t pi_tasks < <( /usr/bin/docker node ps --filter desired-state=running gordonpn-server --format "{{.Name}}" )

/usr/bin/docker swarm ca --rotate --quiet

for service in "${services_array[@]}"; do
	if [ $service == "traefik_traefik" ]; then
		continue
	fi
    /usr/bin/docker service update --force --quiet $service &
done
