#!/usr/bin/env bash

set -o allexport
source /home/gordonpn/workspace/server-services-configs/scripts/.env
set +o allexport

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
source "$script_dir"/trim_logs.sh

BASE_DIR="/Users/gordonpn/workspace/server-services-configs/"

curl -vs --retry 3 https://hc-ping.com/"$UPDATE_HC_UUID"/start
echo

services=(
  # "adguard"
  # "concourse"
  "drone"
  # "filebrowser"
  # "jenkins"
  # "syncthing"
  "traefik"
)

for service in "${services[@]}"; do
  echo "Deploying $service"

  cd "$BASE_DIR"/"$service"/ || break
  /usr/local/bin/docker-compose -f docker-compose.yml config >docker-compose.processed.yml
  /usr/bin/docker stack deploy -c docker-compose.processed.yml "$service"
done

curl -vs --retry 3 https://hc-ping.com/"$UPDATE_HC_UUID"
echo

trim_logs "/media/drive/logs/deploy.log"
