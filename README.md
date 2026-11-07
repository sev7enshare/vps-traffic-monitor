# VPS Traffic Monitor (Soga 实例适配版)

用于监控 VPS 月度总流量并在超限时**自动熔断 Soga 实例服务**，防止 AWS / 腾讯云 / 阿里云等按流量计费被刷爆天价账单。

---

## 🌟 核心特性与架构变更 (v2.0.0-soga)

- **弃用 Docker 依赖**：轻量化架构，无需安装或运行 Docker。
- **专为 Soga 多实例设计**：
  - 自动扫描 `/etc/soga-client/instances/` 目录下的所有节点（如 `36`, `37` 等）。
  - 精确匹配对应的 Systemd 服务单元（如 `soga-36.service`, `soga-37.service`）。
  - 协同管理集中控制服务 `soga-client.service`。
- **自动熔断阻断**：当月流量超出设定的阈值（例如 3000 GiB / 4000 GiB）时，自动通过 `systemctl stop` 关停 Soga 节点。
- **次月 1 号自动唤醒**：每月流量清零恢复后，脚本检测到流量回落，会自动执行 `systemctl start` 将上月被关停的节点全部拉起。
- **Telegram 实时推送**：
  - 🚨 流量熔断报警（附带被关停的服务名单）
  - ✅ 流量恢复通知（附带已重新拉起的节点）
  - 🌙 每日晚间流量消耗日报（23:59 推送当日与当月用量、剩余额度）

---

## 🚀 安装部署

### 1. 一键安装
```bash
sudo bash install.sh
```

### 2. 初次配置
首次安装或运行，脚本会交互式引导配置：
- **Telegram Bot Token**
- **Telegram Chat ID**
- **主机名称**（如 `Linode-IN`）
- **月流量限制 (GiB)**（默认 3000）

配置文件保存在 `/etc/traffic_config.conf`，后续可随时手动编辑修改。

---

## 🛠 手动命令

- **手动触发流量检查与熔断检测**：
  ```bash
  /bin/bash /usr/local/bin/traffic_watch.sh check
  ```
- **手动触发推送今日/当月流量汇总报表**：
  ```bash
  /bin/bash /usr/local/bin/traffic_watch.sh report
  ```
- **查看运行日志**：
  ```bash
  cat /var/log/traffic_watch.log
  ```
