#!/bin/bash
set -e

# Target Kuma Push URL (defined uniquely per node via host environment)
KUMA_URL="${KUMA_HOST_PUSH_URL}"

if [ -z "$KUMA_URL" ]; then
    echo "Error: KUMA_HOST_PUSH_URL environment variable is not set."
    exit 1
fi

# Basic local health check: Validate outgoing internet gateway is reachable
ping -c 3 -W 5 1.1.1.1 > /dev/null || { echo "Outgoing gateway unreachable"; exit 1; }

# Send success ping to Uptime Kuma
if [[ "$KUMA_URL" == *\?* ]]; then
    curl -fsS --retry 3 "${KUMA_URL}"
else
    curl -fsS --retry 3 "${KUMA_URL}?status=up&msg=Host+OK"
fi
