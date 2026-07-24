# VPS Traffic Monitor

## 🚀 简介 (Introduction)
这是一个轻量级的 VPS 流量监控与自动化管理脚本。

⚠️ **特别提示：针对 AWS/GCP 等云服务商 (Especially for AWS, GCP, Azure)**
在亚马逊 AWS、谷歌 GCP 等云平台上，如果服务器没有设置流量上限，且存在异常流量消耗或被黑客利用，可能会产生极高的账单。本项目旨在为你的服务器增加一道“流量安全防线”。

⚠️ **适用范围 (Scope)**
**本项目脚本目前仅支持通过 Docker 容器部署的任务进行熔断控制。** 如果你的任务是以 Systemd 服务或普通二进制进程形式运行，脚本暂无法自动关停，请知悉。

---

## 📊 智能监控与自动化 (Smart Monitoring & Automation)
- **流量熔断：** 当月流量超出预设阈值（默认 3000 GiB）时，自动关停 Docker 容器，防止带宽超标。
- **自动化汇总报告：**
  - **每日晚间汇总：** 每天 23:59，汇报今日及本月流量消耗情况。
  - **运行状态监控：** 汇报服务运行健康状况。
- **Telegram 智能通知：** 流量超标时发送异常通知，流量重置后自动拉起容器并通知恢复。

---

## ⚙️ 依赖说明 (Dependencies)
本脚本会自动通过 `install.sh` 安装以下必备组件：
- **核心工具：** `bc`, `vnstat`, `curl`
- **基础环境：** `python3`, `docker.io`, `cron`

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
