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
    read -p "主机名称: " NODE_NAME
    echo "VPS_TG_TOKEN='$VPS_TG_TOKEN'" > "$CONFIG"
    echo "VPS_TG_CHAT_ID='$VPS_TG_CHAT_ID'" >> "$CONFIG"
    echo "NODE_NAME='$NODE_NAME'" >> "$CONFIG"
    chmod 600 "$CONFIG"
fi
# shellcheck disable=SC1090
source "$CONFIG"

LIMIT_GB=${LIMIT_GB:-3000}
MANAGED_LABEL_KEY=${MANAGED_LABEL_KEY:-traffic_watch}
MANAGED_LABEL_VALUE=${MANAGED_LABEL_VALUE:-true}
MANAGED_LABEL_FILTER="label=${MANAGED_LABEL_KEY}=${MANAGED_LABEL_VALUE}"

INTERFACE=$(ip route | awk '/default/ {print $5; exit}')
IP=$(curl -s --connect-timeout 5 checkip.amazonaws.com)
LOG_FILE="/var/log/traffic_watch.log"
MARKER_FILE="/tmp/docker_stopped_by_traffic"

send_tg() {
    curl -s -X POST "https://api.telegram.org/bot$VPS_TG_TOKEN/sendMessage" \
        -d "chat_id=$VPS_TG_CHAT_ID" \
        -d "text=$1" \
        -d "parse_mode=Markdown" > /dev/null
}

get_vnstat_gib() {
    local period="$1"
    python3 - "$period" <<'PY'
import os
import sys
import json

period = sys.argv[1]
raw = os.environ.get("VNSTAT_JSON", "")

try:
    data = json.loads(raw)
    interfaces = data.get("interfaces") or []
    if not interfaces:
        print("0.00")
        raise SystemExit(0)

    traffic = interfaces[0].get("traffic") or {}
    rows = traffic.get(period) or []
    if not rows:
        print("0.00")
        raise SystemExit(0)

    last = rows[-1] or {}
    rx = float(last.get("rx") or 0)
    tx = float(last.get("tx") or 0)
    print(f"{(rx + tx) / 1024 / 1024 / 1024:.2f}")
except Exception:
    print("0.00")
PY
}

get_managed_containers() {
    docker ps -q --filter "$MANAGED_LABEL_FILTER"
}

# 数据抓取
VNSTAT_JSON=$(vnstat -i "$INTERFACE" --json 2>/dev/null || true)
export VNSTAT_JSON
TOTAL_GIB=$(get_vnstat_gib month)
TODAY_GIB=$(get_vnstat_gib day)
[ -z "$TOTAL_GIB" ] && TOTAL_GIB=0.00
[ -z "$TODAY_GIB" ] && TODAY_GIB=0.00
TOTAL_GIB=$(printf "%.2f" "$TOTAL_GIB")
TODAY_GIB=$(printf "%.2f" "$TODAY_GIB")

if [ "$1" == "check" ] || [ -z "$1" ]; then
    if [ "$(echo "$TOTAL_GIB > $LIMIT_GB" | bc 2>/dev/null)" -eq 1 ]; then
        RUNNING=$(get_managed_containers)
        if [ -n "$RUNNING" ]; then
            printf '%s\n' "$RUNNING" > "$MARKER_FILE"
            send_tg "🚨 *流量熔断* 🚨%0A*主机:* $NODE_NAME%0A*已用:* ${TOTAL_GIB} GiB%0A*限额:* ${LIMIT_GB} GiB%0A*动作:* 关停受管控 Docker 容器"
            docker stop $RUNNING >> "$LOG_FILE" 2>&1
        else
            send_tg "⚠️ *流量超限* ⚠️%0A*主机:* $NODE_NAME%0A*已用:* ${TOTAL_GIB} GiB%0A*限额:* ${LIMIT_GB} GiB%0A*状态:* 未发现带 ${MANAGED_LABEL_KEY}=${MANAGED_LABEL_VALUE} 标签的受管控容器，未执行停机"
        fi
    elif [ -f "$MARKER_FILE" ]; then
        STOPPED=$(cat "$MARKER_FILE")
        if [ -n "$STOPPED" ]; then
            send_tg "✅ *流量恢复* ✅%0A*主机:* $NODE_NAME%0A*动作:* 自动拉起受管控 Docker 容器"
            docker start $STOPPED >> "$LOG_FILE" 2>&1
        fi
        rm -f "$MARKER_FILE"
    fi
elif [ "$1" == "report" ]; then
    if [ "$(echo "$LIMIT_GB > 0" | bc 2>/dev/null)" -eq 1 ]; then
        USAGE_PERCENT=$(echo "scale=2; $TOTAL_GIB * 100 / $LIMIT_GB" | bc)
        REMAINING=$(echo "scale=2; $LIMIT_GB - $TOTAL_GIB" | bc)
    else
        USAGE_PERCENT=0
        REMAINING=0
    fi
    msg="🌙 *流量晚间汇总* 🌙%0A--------------------------%0A*主机:* $NODE_NAME%0A*IP:* $IP%0A*今日消耗:* ${TODAY_GIB} GiB%0A*本月累计:* ${TOTAL_GIB} GiB%0A*使用率:* ${USAGE_PERCENT}%%%0A*剩余额度:* ${REMAINING} GiB%0A*状态:* 正常监控中"
    send_tg "$msg"
fi
