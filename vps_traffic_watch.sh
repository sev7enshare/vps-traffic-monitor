#!/bin/bash
# ========================================================
# VPS Traffic Monitor & Docker Auto-Shield
# Version: 1.2.0
# ========================================================

# 交互式获取配置 (仅在初次运行时或环境变量未设置时)
if [ -z "$VPS_TG_TOKEN" ]; then
    read -p "请输入 Telegram Bot Token: " VPS_TG_TOKEN
    export VPS_TG_TOKEN
fi
if [ -z "$VPS_TG_CHAT_ID" ]; then
    read -p "请输入 Telegram Chat ID: " VPS_TG_CHAT_ID
    export VPS_TG_CHAT_ID
fi
if [ -z "$NODE_NAME" ]; then
    read -p "请输入此节点名称 (如 AWS-JP1): " NODE_NAME
    export NODE_NAME
fi

LIMIT_GB=${LIMIT_GB:-3000}

# 基础环境检查
for cmd in bc vnstat curl docker python3; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: Required command '$cmd' not found."
        exit 1
    fi
done

INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
IP=$(curl -s --connect-timeout 5 checkip.amazonaws.com || curl -s --connect-timeout 5 ipinfo.io/ip)
LOG_FILE="/var/log/traffic_watch.log"
MARKER_FILE="/tmp/docker_stopped_by_traffic"

send_tg() {
    if [ -n "$VPS_TG_TOKEN" ] && [ -n "$VPS_TG_CHAT_ID" ]; then
        curl -s -X POST "https://api.telegram.org/bot$VPS_TG_TOKEN/sendMessage" \
            -d "chat_id=$VPS_TG_CHAT_ID" \
            -d "text=$1" \
            -d "parse_mode=Markdown" > /dev/null
    fi
}

VNSTAT_JSON=$(vnstat -i $INTERFACE --json)
TOTAL_GIB=$(echo "$VNSTAT_JSON" | python3 -c "import sys, json; data=json.load(sys.stdin); m=data['interfaces'][0]['traffic']['month']; print((m[-1]['rx']+m[-1]['tx'])/1024/1024/1024)" 2>/dev/null)

if [ -z "$TOTAL_GIB" ]; then TOTAL_GIB=0; fi

if [ "$1" == "check" ] || [ -z "$1" ]; then
    if [ $(echo "$TOTAL_GIB > $LIMIT_GB" | bc) -eq 1 ]; then
        RUNNING=$(docker ps -q)
        if [ -n "$RUNNING" ]; then
            docker ps -q > "$MARKER_FILE"
            msg="🚨 *流量熔断* 🚨%0A*节点:* $NODE_NAME%0A*使用:* ${TOTAL_GIB} GiB%0A*限额:* ${LIMIT_GB} GiB%0A*动作:* 关停 Docker"
            send_tg "$msg"
            docker stop $RUNNING >> "$LOG_FILE" 2>&1
        fi
    elif [ -f "$MARKER_FILE" ]; then
        STOPPED=$(cat "$MARKER_FILE")
        if [ -n "$STOPPED" ]; then
            msg="✅ *流量恢复* ✅%0A*节点:* $NODE_NAME%0A*动作:* 自动拉起 Docker"
            send_tg "$msg"
            docker start $STOPPED >> "$LOG_FILE" 2>&1
        fi
        rm -f "$MARKER_FILE"
    fi
fi
