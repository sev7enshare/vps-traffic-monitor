#!/bin/bash
apt-get update && apt-get install -y bc vnstat curl python3 docker.io
systemctl enable cron && systemctl start cron
curl -sL https://raw.githubusercontent.com/sev7enshare/vps-traffic-monitor/main/vps_traffic_watch.sh -o /usr/local/bin/traffic_watch.sh
chmod +x /usr/local/bin/traffic_watch.sh
(crontab -l 2>/dev/null | grep -v "traffic_watch.sh" ; \
 echo "*/5 * * * * /bin/bash /usr/local/bin/traffic_watch.sh check" ; \
 echo "59 23 * * * /bin/bash /usr/local/bin/traffic_watch.sh report") | crontab -
/bin/bash /usr/local/bin/traffic_watch.sh check
