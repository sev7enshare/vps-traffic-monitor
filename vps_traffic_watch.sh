#!/bin/bash
# ========================================================
# VPS Traffic Monitor v1.4.0
# 功能：流量熔断、自动恢复、详细流量统计汇总
# ========================================================

CONFIG="/etc/traffic_config.conf"

# 配置加载/初始化
if [ ! -s "$CONFIG" ]; then
    echo "=== 初次配置 ==="
    read -p "Telegram Bot Token: " VPS_TG_TOKEN
    read -p "Telegram Chat ID: " VPS_TG_CHAT_ID
    read -p "节点名称: " NODE_NAME
    echo "VPS_TG_TOKEN='$VPS_TG_TOKEN'" > "$CONFIG"
    echo "VPS_TG_CHAT_ID='$VPS_TG_CHAT_ID'" >> "$CONFIG"
    echo "NODE_NAME='$NODE_NAME'" >> "$CONFIG"
    chmod 600 "$CONFIG"
fi
source "$CONFIG"

LIMIT_GB=${LIMIT_GB:-3000}
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
IP=$(curl -s --connect-timeout 5 checkip.amazonaws.com)
LOG_FILE="/var/log/traffic_watch.log"
MARKER_FILE="/tmp/docker_stopped_by_traffic"

send_tg() {
    curl -s -X POST "https://api.telegram.org/bot$VPS_TG_TOKEN/sendMessage" \
        -d "chat_id=$VPS_TG_CHAT_ID" \
        -d "text=$1" \
        -d "parse_mode=Markdown" > /dev/null
}

# 数据抓取
VNSTAT_JSON=$(vnstat -i $INTERFACE --json)
TOTAL_GIB=$(echo "$VNSTAT_JSON" | python3 -c "import sys, json; data=json.load(sys.stdin); m=data['interfaces'][0]['traffic']['month']; print((m[-1]['rx']+m[-1]['tx'])/1024/1024/1024)" 2>/dev/null)
TODAY_BYTES=$(vnstat -i $INTERFACE -d --oneline b | cut -d ';' -f 6)
TODAY_GIB=$(echo "scale=2; ${TODAY_BYTES:-0} / 1024 / 1024 / 1024" | bc)
[ -z "$TOTAL_GIB" ] && TOTAL_GIB=0
TOTAL_GIB=$(printf "%.2f" $TOTAL_GIB)

if [ "$1" == "check" ] || [ -z "$1" ]; then
    if [ $(echo "$TOTAL_GIB > $LIMIT_GB" | bc) -eq 1 ]; then
        RUNNING=$(docker ps -q)
        if [ -n "$RUNNING" ]; then
            docker ps -q > "$MARKER_FILE"
            send_tg "🚨 *流量熔断* 🚨%0A*节点:* $NODE_NAME%0A*已用:* ${TOTAL_GIB} GiB%0A*限额:* ${LIMIT_GB} GiB%0A*动作:* 关停 Docker"
            docker stop $RUNNING >> "$LOG_FILE" 2>&1
        fi
    elif [ -f "$MARKER_FILE" ]; then
        STOPPED=$(cat "$MARKER_FILE")
        if [ -n "$STOPPED" ]; then
            send_tg "✅ *流量恢复* ✅%0A*节点:* $NODE_NAME%0A*动作:* 自动拉起 Docker"
            docker start $STOPPED >> "$LOG_FILE" 2>&1
        fi
        rm -f "$MARKER_FILE"
    fi
elif [ "$1" == "report" ]; then
    USAGE_PERCENT=$(echo "scale=2; $TOTAL_GIB * 100 / $LIMIT_GB" | bc)
    REMAINING=$(echo "scale=2; $LIMIT_GB - $TOTAL_GIB" | bc)
    msg="🌙 *流量晚间汇总* 🌙%0A--------------------------%0A*节点:* $NODE_NAME%0A*IP:* $IP%0A*今日消耗:* ${TODAY_GIB} GiB%0A*本月累计:* ${TOTAL_GIB} GiB%0A*使用率:* ${USAGE_PERCENT}%%%0A*剩余额度:* ${REMAINING} GiB%0A*状态:* 正常监控中"
    send_tg "$msg"
fi
