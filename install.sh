#!/bin/bash
set -e

VERSION="${VERSION:-v1.6.0}"
SCRIPT_URL="https://raw.githubusercontent.com/sev7enshare/vps-traffic-monitor/${VERSION}/vps_traffic_watch.sh"

apt-get update && apt-get install -y bc vnstat curl python3 docker.io
systemctl enable cron && systemctl start cron

curl -fsSL "$SCRIPT_URL" -o /usr/local/bin/traffic_watch.sh
chmod +x /usr/local/bin/traffic_watch.sh

(crontab -l 2>/dev/null | grep -v "traffic_watch.sh" ; \
 echo "*/5 * * * * /bin/bash /usr/local/bin/traffic_watch.sh check" ; \
 echo "59 23 * * * /bin/bash /usr/local/bin/traffic_watch.sh report") | crontab -

echo
echo "VPS Traffic Monitor installed from ${VERSION}."
echo "Important: only Docker containers with label traffic_watch=true will be stopped when traffic exceeds the limit."
echo "The first run will ask for Telegram settings and the monthly traffic limit in GiB."
echo
echo "docker run example:"
echo "  docker run --label traffic_watch=true ..."
echo
echo "docker compose example:"
echo "  labels:"
echo "    - \"traffic_watch=true\""
echo

/bin/bash /usr/local/bin/traffic_watch.sh check
