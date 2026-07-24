## 自动监控脚本traffic_watch：



####  1. 还是先定义名字，每台机器不同

```
NODE_NAME="AWS-JP1" 
```





#### 2. 直接执行（会自动安装缺失依赖并覆盖旧脚本）

```
apt-get update && apt-get install -y bc cron vnstat curl
systemctl enable cron && systemctl start cron
```









```
cat << 'EOF' > /usr/local/bin/traffic_watch.sh
#!/bin/bash
# ================= 配置区 =================
NODE_NAME="REPLACE_ME_NAME"
TG_TOKEN="8252058275:AAFjo-ZXyTrSBjpUCzIO8616csIdXLGjP1U"
TG_CHAT_ID="710294518"
LIMIT_GB=3000
# ==========================================

INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
IP=$(curl -s --connect-timeout 5 checkip.amazonaws.com || curl -s --connect-timeout 5 ipinfo.io/ip)
LOG_FILE="/var/log/traffic_watch.log"
MARKER_FILE="/tmp/docker_stopped_by_traffic"

send_tg() {
    local text="$1"
    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        -d "chat_id=$TG_CHAT_ID" \
        -d "text=$text" \
        -d "parse_mode=Markdown" > /dev/null
}

to_gib() { echo "scale=2; $1 / 1024 / 1024 / 1024" | bc; }

# 核心流量抓取 (精准处理 GiB/TiB)
VNSTAT_JSON=$(vnstat -i $INTERFACE --json)
# 尝试使用 python3 解析 JSON
MONTH_GIB=$(echo "$VNSTAT_JSON" | python3 -c "import sys, json; data=json.load(sys.stdin); m=data['interfaces'][0]['traffic']['month']; print(m[-1]['rx']+m[-1]['tx'])" 2>/dev/null)

if [ -z "$MONTH_GIB" ]; then
    # 备用方案：解析命令行文本
    MONTH_VAL=$(vnstat -i $INTERFACE -m | grep $(date +%Y-%m) | awk '{print $8}')
    MONTH_UNIT=$(vnstat -i $INTERFACE -m | grep $(date +%Y-%m) | awk '{print $9}')
    if [ "$MONTH_UNIT" == "TiB" ]; then 
        TOTAL_GIB=$(echo "scale=2; $MONTH_VAL * 1024" | bc)
    else 
        TOTAL_GIB=$MONTH_VAL
    fi
else
    TOTAL_GIB=$(echo "scale=2; $MONTH_GIB / 1024 / 1024 / 1024" | bc)
fi

# 执行逻辑
if [ "$1" == "check" ] || [ -z "$1" ]; then
    if [ $(echo "$TOTAL_GIB > $LIMIT_GB" | bc) -eq 1 ]; then
        RUNNING=$(docker ps -q)
        if [ -n "$RUNNING" ]; then
            docker ps -q > "$MARKER_FILE"
            msg="🚨 *流量熔断通知* 🚨%0A--------------------------%0A*主机:* ${NODE_NAME}%0A*IP:* ${IP}%0A*已用:* ${TOTAL_GIB} GiB%0A*限额:* ${LIMIT_GB} GiB%0A*状态:* 超过阈值，已强制关停 Docker！"
            send_tg "$msg"
            docker stop $RUNNING >> "$LOG_FILE" 2>&1
        fi
    else
        if [ -f "$MARKER_FILE" ]; then
            STOPPED=$(cat "$MARKER_FILE")
            if [ -n "$STOPPED" ]; then
                msg="✅ *流量恢复正常* ✅%0A--------------------------%0A*主机:* ${NODE_NAME}%0A*IP:* ${IP}%0A*已用:* ${TOTAL_GIB} GiB%0A*状态:* 流量重置，正在自动拉起 Docker。"
                send_tg "$msg"
                docker start $STOPPED >> "$LOG_FILE" 2>&1
            fi
            rm -f "$MARKER_FILE"
        fi
    fi
elif [ "$1" == "report" ]; then
    TODAY_BYTES=$(vnstat -i $INTERFACE -d --oneline b | cut -d ';' -f 6)
    if [ -z "$TODAY_BYTES" ]; then TODAY_GIB="0"; else TODAY_GIB=$(to_gib $TODAY_BYTES); fi
    USAGE_PERCENT=$(echo "scale=2; $TOTAL_GIB * 100 / $LIMIT_GB" | bc)
    msg="🌙 *流量晚间汇总* 🌙%0A--------------------------%0A*主机:* ${NODE_NAME}%0A*IP:* ${IP}%0A*今日消耗:* ${TODAY_GIB} GiB%0A*本月累计:* ${TOTAL_GIB} GiB%0A*使用率:* ${USAGE_PERCENT}%25%0A*剩余额度:* $(echo "$LIMIT_GB - $TOTAL_GIB" | bc) GiB%0A*设备状态:* 正常监控中"
    send_tg "$msg"
fi
EOF

```





#### 3.修复名称并赋予权限

```bash
sed -i "s/REPLACE_ME_NAME/$NODE_NAME/g" /usr/local/bin/traffic_watch.sh
chmod +x /usr/local/bin/traffic_watch.sh
```







### 4.重新设置定时任务

```
(crontab -l 2>/dev/null | grep -v "traffic_watch.sh" ; \
 echo "*/5 * * * * /bin/bash /usr/local/bin/traffic_watch.sh check" ; \
 echo "59 23 * * * /bin/bash /usr/local/bin/traffic_watch.sh report") | crontab -

echo "✅ $NODE_NAME 升级完成！"
```



#### 5.检查并测试

- **手动触发一次熔断检查**（这会立刻关掉你刚才开的 Docker）：

```
/bin/bash /usr/local/bin/traffic_watch.sh check
```

- **手动触发一次汇总报告**：

  ```
  /bin/bash /usr/local/bin/traffic_watch.sh report
  ```

  

#### 6.**修改限额命令：**

(如果你希望这台机器在 7 月份剩下的时间里**继续运行**（哪怕要交超额费），你需要把脚本里的限制调大。)

- 如果你调到了 6000，脚本检测到 5109 < 6000，就不会再关掉你的容器了。等到 8 月 1 号，记得改回 3000。

```
sed -i 's/LIMIT_GB=3000/LIMIT_GB=6000/g' /usr/local/bin/traffic_watch.sh
```





#### 7.关于 每 月 1 号的自动恢复：

- **本机器 (AWS-JP)**：由于它现在是“超支”状态，Docker 已经被关掉。等到 8 月 1 号 vnstat 清零，脚本检测到 0.00 GiB < 3000 GiB，它会**自动发送一条“流量恢复通知”**到 Telegram，并把你的 soga 节点全部拉起来。你不需要定闹钟去手动开启，完全自动化。
- **其他未超标机器**：会每晚准时给你发“晚间汇总”，像贴身管家一样汇报健康状况。

#### 8. 
如何手动测试？
你可以手动运行一次脚本查看是否有报错：
/bin/bash /usr/local/bin/traffic_watch.sh
（如果流量没超且容器都开着，它不会发消息，这代表正常）。

如何修改限额？
如果有的机器套餐是 2TB，执行：
nano /usr/local/bin/traffic_watch.sh
找到 LIMIT_GB=3000 修改为 2000，保存 (Ctrl+O, Enter) 退出 (Ctrl+X) 即可。

日志查看：
随时可以执行 tail -f /var/log/traffic_watch.log 看看它的历史操作。
