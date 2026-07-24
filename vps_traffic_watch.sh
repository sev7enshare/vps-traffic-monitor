#!/bin/bash
# ========================================================
# VPS Traffic Monitor v1.3.0
# 功能：流量监控、Docker 熔断、持久化配置
# ========================================================

# 配置文件
CONFIG="/etc/traffic_config.conf"

# 1. 持久化配置逻辑
if [ -f "$CONFIG" ]; then
    source "$CONFIG"
else
    echo "=== 初次配置，请输入信息 ==="
    read -p "请输入 Telegram Bot Token: " VPS_TG_TOKEN
    read -p "请输入 Telegram Chat ID: " VPS_TG_CHAT_ID
    read -p "请输入节点名称: " NODE_NAME
    echo "VPS_TG_TOKEN='$VPS_TG_TOKEN'" > "$CONFIG"
    echo "VPS_TG_CHAT_ID='$VPS_TG_CHAT_ID'" >> "$CONFIG"
    echo "NODE_NAME='$NODE_NAME'" >> "$CONFIG"
    chmod 600 "$CONFIG"
fi

LIMIT_GB=${LIMIT_GB:-3000}

# 基础检查
for cmd in bc vnstat curl docker python3; do
    if ! command -v $cmd &> /dev/null; then echo "Missing dependency: $cmd"; exit 1; fi
done

INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
LOG_FILE="/var/log/traffic_watch.log"
MARKER_FILE="/tmp/docker_stopped_by_traffic"

send_tg() {
    curl -s -X POST "https://api.telegram.org/bot$VPS_TG_TOKEN/sendMessage" \
        -d "chat_id=$VPS_TG_CHAT_ID" \
        -d "text=$1" \
        -d "parse_mode=Markdown" > /dev/null
}

VNSTAT_JSON=$(vnstat -i $INTERFACE --json)
TOTAL_GIB=$(echo "$VNSTAT_JSON" | python3 -c "import sys, json; data=json.load(sys.stdin); m=data['interfaces'][0]['traffic']['month']; print((m[-1]['rx']+m[-1]['tx'])/1024/1024/1024)" 2>/dev/null)
[ -z "$TOTAL_GIB" ] && TOTAL_GIB=0

if [ "$1" == "check" ] || [ -z "$1" ]; then
    if [ $(echo "$TOTAL_GIB > $LIMIT_GB" | bc) -eq 1 ]; then
        RUNNING=$(docker ps -q)
        if [ -n "$RUNNING" ]; then
            docker ps -q > "$MARKER_FILE"
            send_tg "🚨 *流量熔断* 🚨%0A*节点:* $NODE_NAME%0A*已用:* ${TOTAL_GIB} GiB%0A*动作:* 关停 Docker"
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
    msg="🌙 *流量晚间汇总* 🌙%0A*节点:* $NODE_NAME%0A*累计:* ${TOTAL_GIB} GiB%0A*剩余:* $(echo "$LIMIT_GB - $TOTAL_GIB" | bc) GiB%0A*状态:* 正常监控中"
    send_tg "$msg"
fi
