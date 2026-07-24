# VPS Traffic Monitor

## 🚀 简介 (Introduction)
这是一个轻量级的 VPS 流量监控与自动化管理脚本。它可以实时监控服务器流量，在超标时自动关停 Docker，并自动拉起。

## ⚙️ 依赖说明 (Dependencies)
本脚本会自动通过安装脚本安装以下依赖：
- `bc`, `vnstat`, `curl`, `python3`, `docker.io`, `cron`

## 🛠️ 一键部署 (Quick Deployment)
在你的 VPS 上运行以下命令即可完成部署：
```bash
bash <(curl -sL https://raw.githubusercontent.com/sev7enshare/vps-traffic-monitor/main/install.sh)
```

## 📝 配置说明 (Configuration)
脚本支持交互式配置，初次运行会自动引导：
- `VPS_TG_TOKEN`: Telegram Bot Token
- `VPS_TG_CHAT_ID`: 接收通知的 Chat ID
- `LIMIT_GB`: 流量限额 (默认 3000 GiB)

---

## 🛡️ 安全承诺 (Safety)
本脚本**已完全脱敏**，不会存储任何敏感凭据。
