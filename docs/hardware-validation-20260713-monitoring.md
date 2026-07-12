# 2026-07-13 LuCI 统计与温度验证

## 构建

- OpenWrt commit：`4984eff3c34a5b8d7995e2b2a0a3823bba31c1fc`
- 完整构建退出状态：`0`
- sysupgrade 大小：`59,146,535` 字节
- sysupgrade SHA256：
  `cc0ac57ee64478429e551536cc7fddd2604558d788ac70b53adc7dbd787d7558`
- SquashFS：约 `52.34 MiB`

manifest 已确认包含：

- `luci-app-statistics`
- `luci-i18n-statistics-zh-cn`
- `collectd` 及 CPU、内存、负载、接口、RRDTool、thermal 插件
- `rrdtool1`
- `xg040g-monitoring-defaults`

## 实机结果

- 使用保留配置的 `sysupgrade`，约 60 秒恢复 SSH。
- One-KVM 保持启用并正常运行。
- 管理接口仍为 DHCP 客户端；PXE 地址仍为 `10.40.0.1/24`。
- 内核 thermal zone 类型为 `cpu-thermal`。
- 实测温度在约 `66.8-71.5 C` 之间变化。
- collectd thermal 插件成功加载并进入 read loop。
- 已生成 `/tmp/rrd/xg040g-f5040c/thermal-thermal_zone0/temperature.rrd`。
- LuCI“统计 -> 图表 -> 温感”成功显示温度历史曲线。
- overlay 刷机后可用空间约 `164.0 MiB`。

RRD 数据保存在 `/tmp/rrd`，默认不备份到 flash，重启后重新采集。
