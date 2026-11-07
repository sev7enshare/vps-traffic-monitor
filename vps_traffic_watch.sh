#!/bin/bash
# ========================================================
# VPS Traffic Monitor for Soga v2.0.0
# 功能：Soga原生多实例流量熔断、次月自动恢复、Telegram报表通知
# ========================================================

CONFIG="/etc/traffic_config.conf"

# 配置加载/初始化
if [ ! -s "$CONFIG" ]; then
    echo "=== 初次配置 (Soga 实例监控版) ==="
    read -p "Telegram Bot Token: " VPS_TG_TOKEN
    read -p "Telegram Chat ID: " VPS_TG_CHAT_ID
    read -p "主机名称: " NODE_NAME
    while true; do
        read -p "月流量限制 GiB [默认 3000]: " LIMIT_GB_INPUT
        LIMIT_GB="${LIMIT_GB_INPUT:-3000}"
        LIMIT_GB_VALID=$(echo "$LIMIT_GB > 0" | bc 2>/dev/null || true)
        if [ "$LIMIT_GB_VALID" = "1" ]; then
            break
        fi
        echo "请输入大于 0 的数字，例如 3000"
    done
    echo "VPS_TG_TOKEN='$VPS_TG_TOKEN'" > "$CONFIG"
    echo "VPS_TG_CHAT_ID='$VPS_TG_CHAT_ID'" >> "$CONFIG"
    echo "NODE_NAME='$NODE_NAME'" >> "$CONFIG"
    echo "LIMIT_GB='$LIMIT_GB'" >> "$CONFIG"
    echo "SOGA_INSTANCES_DIR='/etc/soga-client/instances'" >> "$CONFIG"
    chmod 600 "$CONFIG"
fi
# shellcheck disable=SC1090
source "$CONFIG"

LIMIT_GB=${LIMIT_GB:-3000}
SOGA_INSTANCES_DIR=${SOGA_INSTANCES_DIR:-"/etc/soga-client/instances"}

INTERFACE=$(ip route 2>/dev/null | awk '/default/ {print $5; exit}')
IP=$(curl -s --connect-timeout 5 checkip.amazonaws.com || curl -s --connect-timeout 5 ipinfo.io/ip || echo "Unknown")
LOG_FILE="/var/log/traffic_watch.log"
STATE_DIR="/var/lib/traffic-watch"
MARKER_FILE="$STATE_DIR/soga_stopped_by_traffic"
NO_INSTANCE_ALERT_FILE="$STATE_DIR/no_soga_instance_alerted"

mkdir -p "$STATE_DIR"

send_tg() {
    curl -s -X POST "https://api.telegram.org/bot$VPS_TG_TOKEN/sendMessage" \
        -d "chat_id=$VPS_TG_CHAT_ID" \
        -d "text=$1" \
        -d "parse_mode=Markdown" > /dev/null
}

markdown_escape() {
    printf '%s' "$1" | sed \
        -e 's/\\/\\\\/g' \
        -e 's/_/\\_/g' \
        -e 's/\*/\\*/g' \
        -e 's/`/\\`/g' \
        -e 's/\[/\\[/g'
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

# 动态获取当前所有运行中的 Soga 实例服务
get_running_soga_services() {
    local running_services=""
    # 1. 扫描 /etc/soga-client/instances/ 目录下的所有数字实例 (例如 36, 37)
    if [ -d "$SOGA_INSTANCES_DIR" ]; then
        for inst in "$SOGA_INSTANCES_DIR"/*; do
            if [ -d "$inst" ]; then
                local node_id
                node_id=$(basename "$inst")
                local svc_name="soga-${node_id}.service"
                if systemctl is-active --quiet "$svc_name" 2>/dev/null; then
                    running_services="${running_services}${svc_name} "
                fi
            fi
        done
    fi

    # 2. 如果存在集中管理客户端 soga-client.service 且正在运行，也纳入管理
    if systemctl is-active --quiet "soga-client.service" 2>/dev/null; then
        running_services="${running_services}soga-client.service "
    fi

    echo "$running_services" | xargs
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
SAFE_NODE_NAME=$(markdown_escape "$NODE_NAME")
SAFE_IP=$(markdown_escape "$IP")

if [ "$1" == "check" ] || [ -z "$1" ]; then
    LIMIT_EXCEEDED=$(echo "$TOTAL_GIB > $LIMIT_GB" | bc 2>/dev/null || true)
    if [ "$LIMIT_EXCEEDED" = "1" ]; then
        RUNNING=$(get_running_soga_services)
        if [ -n "$RUNNING" ]; then
            printf '%s\n' "$RUNNING" > "$MARKER_FILE"
            rm -f "$NO_INSTANCE_ALERT_FILE"
            SAFE_RUNNING=$(markdown_escape "$RUNNING")
            send_tg "🚨 *流量熔断* 🚨%0A*主机:* $SAFE_NODE_NAME%0A*IP:* $SAFE_IP%0A*已用:* ${TOTAL_GIB} GiB%0A*限额:* ${LIMIT_GB} GiB%0A*动作:* 已关停 Soga 实例服务%0A*受影响服务:* \`$SAFE_RUNNING\`"
            for svc in $RUNNING; do
                systemctl stop "$svc" >> "$LOG_FILE" 2>&1
            done
        elif [ ! -f "$NO_INSTANCE_ALERT_FILE" ] && [ ! -f "$MARKER_FILE" ]; then
            send_tg "⚠️ *流量超限* ⚠️%0A*主机:* $SAFE_NODE_NAME%0A*已用:* ${TOTAL_GIB} GiB%0A*限额:* ${LIMIT_GB} GiB%0A*状态:* 未发现活跃的 Soga 实例服务，请检查 $SOGA_INSTANCES_DIR"
            date -u +"%Y-%m-%dT%H:%M:%SZ" > "$NO_INSTANCE_ALERT_FILE"
        fi
    elif [ -f "$MARKER_FILE" ]; then
        STOPPED=$(cat "$MARKER_FILE")
        if [ -n "$STOPPED" ]; then
            SAFE_STOPPED=$(markdown_escape "$STOPPED")
            send_tg "✅ *流量恢复* ✅%0A*主机:* $SAFE_NODE_NAME%0A*动作:* 流量已清零，自动拉起 Soga 实例服务%0A*已启动服务:* \`$SAFE_STOPPED\`"
            for svc in $STOPPED; do
                systemctl start "$svc" >> "$LOG_FILE" 2>&1
            done
        fi
        rm -f "$MARKER_FILE"
        rm -f "$NO_INSTANCE_ALERT_FILE"
    else
        rm -f "$NO_INSTANCE_ALERT_FILE"
    fi
elif [ "$1" == "report" ]; then
    LIMIT_GB_VALID=$(echo "$LIMIT_GB > 0" | bc 2>/dev/null || true)
    if [ "$LIMIT_GB_VALID" = "1" ]; then
        USAGE_PERCENT=$(echo "scale=2; $TOTAL_GIB * 100 / $LIMIT_GB" | bc)
        REMAINING=$(echo "scale=2; $LIMIT_GB - $TOTAL_GIB" | bc)
    else
        USAGE_PERCENT=0
        REMAINING=0
    fi
    CURRENT_INSTANCES=$(get_running_soga_services)
    [ -z "$CURRENT_INSTANCES" ] && CURRENT_INSTANCES="无运行中实例"
    SAFE_CURR=$(markdown_escape "$CURRENT_INSTANCES")
    msg="🌙 *Soga 流量晚间汇总* 🌙%0A--------------------------%0A*主机:* $SAFE_NODE_NAME%0A*IP:* $SAFE_IP%0A*今日消耗:* ${TODAY_GIB} GiB%0A*本月累计:* ${TOTAL_GIB} GiB%0A*使用率:* ${USAGE_PERCENT}%%%0A*剩余额度:* ${REMAINING} GiB%0A*运行中服务:* \`$SAFE_CURR\`%0A*状态:* 正常监控中"
    send_tg "$msg"
fi
