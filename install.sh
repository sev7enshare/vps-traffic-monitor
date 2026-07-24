#!/bin/bash
# 一键安装脚本 - v1.3.1

# 1. 自动安装依赖
apt-get update && apt-get install -y bc vnstat curl python3 docker.io
systemctl enable cron && systemctl start cron

# 2. 拉取监控脚本
curl -sL https://raw.githubusercontent.com/sev7enshare/vps-traffic-monitor/main/vps_traffic_watch.sh -o /usr/local/bin/traffic_watch.sh
chmod +x /usr/local/bin/traffic_watch.sh

# 3. 强制配置定时任务 (确保使用最新的脚本路径和参数)
(crontab -l 2>/dev/null | grep -v "traffic_watch.sh" ; \
 echo "*/5 * * * * /bin/bash /usr/local/bin/traffic_watch.sh check" ; \
 echo "59 23 * * * /bin/bash /usr/local/bin/traffic_watch.sh report") | crontab -

echo "安装完成！"
echo "正在触发首次配置引导..."
/bin/bash /usr/local/bin/traffic_watch.sh check
