#!/bin/bash
# 一键安装脚本 - v1.2.2

echo "=== 正在配置 VPS 流量监控系统 ==="

# 1. 安装系统依赖
echo "正在检查并安装系统依赖..."
apt-get update && apt-get install -y bc vnstat curl python3 docker.io
systemctl enable cron && systemctl start cron

# 2. 拉取监控脚本
echo "正在拉取最新脚本..."
curl -sL https://raw.githubusercontent.com/sev7enshare/vps-traffic-monitor/main/vps_traffic_watch.sh -o /usr/local/bin/traffic_watch.sh
chmod +x /usr/local/bin/traffic_watch.sh

# 3. 配置定时任务 (每 5 分钟检查，每晚 23:59 汇总)
echo "正在配置定时任务..."
(crontab -l 2>/dev/null | grep -v "traffic_watch.sh" ; \
 echo "*/5 * * * * /bin/bash /usr/local/bin/traffic_watch.sh check" ; \
 echo "59 23 * * * /bin/bash /usr/local/bin/traffic_watch.sh report") | crontab -

echo "=== 安装完成 ==="
echo "正在进行首次配置，请根据提示输入信息："
/bin/bash /usr/local/bin/traffic_watch.sh check
