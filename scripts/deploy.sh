#!/usr/bin/env bash

set -o allexport
source /home/gordonpn/workspace/server-services-configs/scripts/.env
set +o allexport

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
source "$script_dir"/trim_logs.sh

BASE_DIR="/home/gordonpn/workspace/server-services-configs"

curl -s --retry 3 https://hc-ping.com/"$UPDATE_HC_UUID"/start
echo

services=(
  "adguard"
  # "concourse"
  "drone"
  # "filebrowser"
  # "jenkins"
  "syncthing"
  "traefik"
)

for service in "${services[@]}"; do
  echo "Deploying $service"

  cd "$BASE_DIR"/"$service"/ || break
  /usr/local/bin/docker-compose -f docker-compose.yml config >docker-compose.processed.yml
  echo -e "version: \"3.8\"\n$(cat docker-compose.processed.yml)" >docker-compose.processed.yml
  /usr/bin/docker stack deploy -c docker-compose.processed.yml "$service"
done

curl -s --retry 3 https://hc-ping.com/"$UPDATE_HC_UUID"
echo

trim_logs "/media/drive/logs/deploy.log"
