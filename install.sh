#!/bin/bash
set -e

VERSION="${VERSION:-soga-v}"

# 移除对 docker.io 的依赖，仅安装必要的基础工具
apt-get update && apt-get install -y bc vnstat curl python3
systemctl enable cron && systemctl start cron
systemctl enable vnstat && systemctl start vnstat

TARGET_PATH="/usr/local/bin/traffic_watch.sh"

# 如果是本地同目录运行，则优先从本地复制；否则从 GitHub 对应分支拉取
if [ -f "./vps_traffic_watch.sh" ]; then
    cp -f "./vps_traffic_watch.sh" "$TARGET_PATH"
else
    SCRIPT_URL="https://raw.githubusercontent.com/sev7enshare/vps-traffic-monitor/${VERSION}/vps_traffic_watch.sh"
    curl -fsSL "$SCRIPT_URL" -o "$TARGET_PATH"
fi

chmod +x "$TARGET_PATH"

# 配置日志轮转 (logrotate)，防止日志无限膨胀，保留最近 4 周日志并自动压缩
if [ -d "/etc/logrotate.d" ]; then
    cat > /etc/logrotate.d/traffic_watch << 'EOF'
/var/log/traffic_watch.log {
    weekly
    rotate 4
    missingok
    notifempty
    compress
    copytruncate
}
EOF
fi

# 注册定时任务：每 5 分钟检查一次流量是否超限，每天 23:59 发送一次晚间流量汇总
(crontab -l 2>/dev/null | grep -v "traffic_watch.sh" ; \
 echo "*/5 * * * * /bin/bash /usr/local/bin/traffic_watch.sh check" ; \
 echo "59 23 * * * /bin/bash /usr/local/bin/traffic_watch.sh report") | crontab -

echo
echo "=========================================================="
echo " VPS Traffic Monitor for Soga 已成功安装 (${VERSION})"
echo "=========================================================="
echo "监控目标: /etc/soga-client/instances/ 下的所有 Soga 实例服务及 soga-client"
echo "日志管理: 已自动配置 /etc/logrotate.d/traffic_watch 每周轮转与压缩"
echo "当月流量超出限额时将自动执行 systemctl stop 阻断服务并发送 Telegram 报警。"
echo "次月 1 号流量清零后，将自动执行 systemctl start 重新恢复服务。"
echo

/bin/bash "$TARGET_PATH" check
