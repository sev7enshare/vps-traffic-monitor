# VPS Traffic Monitor

## 🚀 简介 (Introduction)
这是一个轻量级的 VPS 流量监控与自动化管理脚本。

## 🛠️ 一键部署 (Quick Deployment)
安装脚本会自动检查并安装以下必需依赖：
- `bc`, `vnstat`, `curl`, `python3`, `docker.io`, `cron`

在你的 VPS 上运行以下命令即可：
```bash
bash <(curl -sL https://raw.githubusercontent.com/sev7enshare/vps-traffic-monitor/main/install.sh)
```

## 📝 配置说明 (Configuration)
- `VPS_TG_TOKEN`: 你的 Telegram Bot API Token。
- `VPS_TG_CHAT_ID`: 接收通知的个人 Chat ID。
- `LIMIT_GB`: 流量熔断阈值（默认 3000 GiB）。
