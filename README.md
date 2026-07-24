# VPS Traffic Monitor

## 🚀 简介 (Introduction)
这是一个轻量级的 VPS 流量监控与自动化管理脚本。它可以实时监控你的服务器流量使用情况，并在达到预设阈值时自动执行操作（如关停 Docker 容器），防止流量超标导致的费用激增。

This is a lightweight VPS traffic monitoring and management script. It monitors your server's traffic usage in real-time and automatically executes actions (such as stopping Docker containers) when a predefined threshold is reached, preventing unexpected cost overruns.

---

## ✨ 核心功能 (Key Features)
- **流量熔断 (Traffic Shielding):** 流量超标时自动关停 Docker 容器，防止“流量刺客”。
- **自动恢复 (Auto-Recovery):** 每月初流量重置时，自动识别并恢复之前关停的容器。
- **配置灵活 (Flexible Config):** 支持通过环境变量自定义限额和节点名称。
- **智能通知 (Smart Alerts):** 通过 Telegram Bot 发送实时状态通知。

---

## 🛠️ 一键部署 (Quick Deployment)

在你的 VPS 上运行以下命令即可完成部署：

```bash
# 设置环境变量 (Set Environment Variables)
export VPS_TG_TOKEN="你的Telegram_Bot_Token"
export VPS_TG_CHAT_ID="你的Telegram_Chat_ID"
export LIMIT_GB=3000

# 一键安装 (Quick Install)
bash <(curl -sL https://raw.githubusercontent.com/sev7enshare/vps-traffic-monitor/main/install.sh)
```

---

## 📝 配置说明 (Configuration)
- `VPS_TG_TOKEN`: 你的 Telegram Bot API Token。
- `VPS_TG_CHAT_ID`: 接收通知的个人 Chat ID。
- `LIMIT_GB`: 流量熔断阈值（单位：GiB，默认 3000）。

---

## 🛡️ 安全承诺 (Safety)
本脚本**已完全脱敏**，不会在代码中存储任何敏感信息。所有凭证均通过环境变量注入，确保你的账户安全。
