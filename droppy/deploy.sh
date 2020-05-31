#!/usr/bin/env bash
/usr/local/bin/docker-compose -f docker-compose.yml config > docker-compose.processed.yml
/usr/bin/docker stack deploy -c docker-compose.processed.yml droppy