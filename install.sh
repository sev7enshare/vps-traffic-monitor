#!/bin/bash
# 一键安装脚本
echo "正在安装监控脚本..."
apt-get update && apt-get install -y bc vnstat curl docker.io python3
curl -sL https://raw.githubusercontent.com/sev7enshare/vps-traffic-monitor/main/vps_traffic_watch.sh -o /usr/local/bin/traffic_watch.sh
chmod +x /usr/local/bin/traffic_watch.sh
(crontab -l 2>/dev/null | grep -v "traffic_watch.sh" ; echo "*/5 * * * * /bin/bash /usr/local/bin/traffic_watch.sh check") | crontab -
echo "安装完成！请设置环境变量 VPS_TG_TOKEN 和 VPS_TG_CHAT_ID。"
