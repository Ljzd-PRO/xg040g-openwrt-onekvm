# 2.5G 软件交换性能

XG-040G-MD 的 2.5G 口是独立的 `eth1`，三个千兆口则位于 MT7530 DSA
交换芯片上。2.5G 口与千兆口之间的流量需要经过 AN7581 CPU 和 Linux bridge，
并不是四个端口都由同一块交换芯片进行硬件转发。

本固件使用 OpenWrt 原生 RPS 改善多连接软件转发，并提供可选的 CPU 固定频率
控制。发布默认保持原厂 1200 MHz，不会自动超频。

## 默认优化

固件默认设置：

```uci
config globals 'globals'
	option packet_steering '2'
```

模式 `2` 会让 OpenWrt 为 `eth0` 和 `eth1` 的 RX 队列使用全部四个 CPU。当前
硬件上的预期 RPS 掩码为十六进制 `f`，表示 CPU0 到 CPU3。

RPS 按数据流分配接收处理，适合 2.5G 主机同时访问多个千兆终端的场景。它不会
拆分一条有序 TCP 流，不能让单个千兆口超过 1 Gbit/s，也不会把 `eth1` 变成
MT7530 的硬件交换端口。

固件不强制修改 GRO、GSO、TSO 和 checksum offload，继续使用内核与驱动默认
设置。也不会自动启用 NPU/PPE TC flower、XPS、irqbalance、IRQ affinity、
flow offload 或额外网络 sysctl。

## LuCI 设置

打开“系统 -> 交换性能”，可以查看：

- 当前 CPU 频率和 SoC 温度；
- 保存的启动频率策略；
- `eth0`、`eth1` RX 队列数量和 RPS 掩码；
- 四个 CPU 的 `NET_RX` 计数；
- `br-lan`、`br-pxe` 成员和 2.5G 链路状态。

“接收数据包分流”提供三个模式：

| 模式 | 行为 |
| --- | --- |
| 关闭 | 不为 RX 队列启用 RPS |
| 自动 | 由 OpenWrt 选择 CPU |
| 全部 CPU 核心 | 使用全部四个核心，本固件默认值 |

应用 RPS 模式只会重载 OpenWrt packet steering 服务，不会重启整个网络。选择或
关闭 PXE 专用端口时，固件也会保留该设置并重新应用队列掩码。

## CPU 频率

默认配置为：

```uci
config cpu 'cpu'
	option overclock '0'
	option frequency '1200'
	option thermal_revert '85'
	option thermal_emergency '95'
```

专用内核模块只在 `nokia,xg-040g-md-tcboot` 上加载。模块加载时仅读取当前
PLL，不会改变频率；仅允许 1200、1300 和 1400 MHz，也不会修改 CPU 电压。

1300/1400 MHz 是实验功能。LuCI 会显示风险警告，并要求输入 `OVERCLOCK`
后才会应用和保存。开启后固件每 5 秒检查温度：

- 达到 85°C：恢复 1200 MHz，并关闭持久超频；
- 达到 95°C：先恢复 1200 MHz，再请求重启；
- 温度、PLL 回读异常或发现上次异常结束标记：恢复 1200 MHz。

这些保护只能降低风险，不能保证每台设备在超频后稳定。散热、环境温度和芯片
个体差异都会影响结果。远程无人值守设备建议始终使用默认 1200 MHz。

## SSH 检查和恢复

查看完整状态：

```sh
xg040g-cpuctl status
```

检查 RPS：

```sh
uci -q get network.globals.packet_steering
for dev in eth0 eth1; do
	for queue in /sys/class/net/$dev/queues/rx-*/rps_cpus; do
		printf '%s ' "$queue"
		cat "$queue"
	done
done
grep NET_RX /proc/softirqs
```

无条件恢复并持久保存原厂频率：

```sh
xg040g-cpuctl restore-stock
```

临时设置频率，不修改已保存的启动策略：

```sh
xg040g-cpuctl set 1200
xg040g-cpuctl set 1300
xg040g-cpuctl set 1400
```

高于 1200 MHz 的命令仍会检查温度、频率白名单和 PLL 回读。

## 正确测试聚合吞吐

一台 2.5G 主机和一台千兆主机只能测得单条约 1 Gbit/s 路径。验证聚合能力至少
需要一台 2.5G 主机连接 `eth1`，并让两台千兆主机分别连接两个 DSA 端口，同时
发起独立 `iperf3` 流量。

测试时应同时记录：

- 每个端口的收发速率；
- `/proc/softirqs` 中各 CPU 的 `NET_RX` 增量；
- CPU 占用、SoC 温度、丢包和 TCP 重传；
- 1200 MHz 下 RPS 关闭、自动和全核模式的差异。

在完成多终端测试前，不应把单端口约 930 Mbit/s 结果描述为 2.5G 聚合线速。

## 技术来源与限制

PLL 模块和温控策略适配自
[`Ljzd-PRO/xg040g-openwrt-switch`](https://github.com/Ljzd-PRO/xg040g-openwrt-switch)
commit `22bd32ab0cb417138763174f3840a67584ff63cf`。本项目改变了默认策略：参考
固件默认 1400 MHz，而本固件始终默认 1200 MHz，仅保留手动实验入口。

参考项目已经确认 PPE/TC flower 规则即使显示 `in_hw`，在 DSA 到 `eth1` 的
方向仍会造成稳定丢包。因此本固件不会移植该硬件转发路径。
