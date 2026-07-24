# VPS Traffic Monitor

## 🚀 简介 (Introduction)
这是一个轻量级的 VPS 流量监控与自动化管理脚本。

⚠️ **特别提示：针对 AWS/GCP 等云服务商 (Especially for AWS, GCP, Azure)**
在亚马逊 AWS、谷歌 GCP 等云平台上，如果服务器没有设置流量上限，且存在异常流量消耗或被黑客利用，可能会产生极高的账单。本项目旨在为你的服务器增加一道“流量安全防线”，通过实时监控并自动触发熔断机制，极大降低因流量超标导致的财务风险。

---

## 📊 智能监控与自动化 (Smart Monitoring & Automation)
- **流量熔断：** 当月流量超出预设阈值（默认 3000 GiB）时，自动关停 Docker 容器，防止带宽超标。
- **自动化汇总报告：**
  - **每日晚间汇总：** 脚本会自动统计今日消耗流量、本月累计消耗、流量使用率及剩余额度。
  - **运行状态报告：** 汇报当前监控服务是否正常。
- **Telegram 智能通知：**
  - **异常通知：** 流量一旦超标，立即发送 Telegram 警报，告知熔断详情（IP、使用量、限额）。
  - **恢复通知：** 流量周期重置后，自动拉起 Docker 容器，并通知流量已恢复。

---

## ⚙️ 依赖说明 (Dependencies)
本脚本会自动通过 `install.sh` 安装以下必备组件：
- **核心工具：** `bc`, `vnstat`, `curl`
- **基础环境：** `python3`, `docker.io` (用于容器熔断), `cron` (用于定时任务)

## 🛠️ 一键部署 (Quick Deployment)
在你的 VPS 上运行以下命令即可：
```bash
bash <(curl -sL https://raw.githubusercontent.com/sev7enshare/vps-traffic-monitor/main/install.sh)
```

## 📝 配置说明 (Configuration)
- **初次运行：** 脚本会自动引导你输入 Telegram Bot Token、Chat ID 和节点名称。
- **流量限制：** 默认为 3000 GiB，可以通过系统环境变量 `LIMIT_GB` 进行调整。

---

## 🛡️ 安全承诺 (Safety)
本脚本**已完全脱敏**，不会在代码中存储任何敏感信息。所有凭证均通过环境变量注入，确保你的账户安全。
