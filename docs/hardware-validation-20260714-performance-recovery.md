# 2026-07-14 性能固件恢复与安全收敛

## 事件

保留配置刷入首个包含全核 RPS、AN7581 PLL 模块和“交换性能”LuCI
的 One-KVM 固件后，设备未恢复正常管理网络。刷机前已完成系统配置和
`/etc/one-kvm` 独立备份。

失败固件的 sysupgrade SHA256 为：

```text
100b101f6ad53fd041f01841ca5299afb871355606f6aaf21d02d2b0efcc507b
```

设备没有硬件变砖，tcboot Web U-Boot 仍可正常进入。但是 factory 恢复会重建
UBI overlay，因此失败启动期间的内核和 procd 日志无法在恢复后取回。本报告
不把 PLL 模块或 RPS 任一项写成已确定根因。

## 恢复路径

1. NUC 保留上游网络地址，同时在同一网卡添加 `192.168.1.2/24`。
2. tcboot uIP 对普通 curl 连续分段上传会停滞，改用每次 480 字节、等待 TCP ACK
   后再发下一段的上传器。
3. 上传 16 MiB 基础 factory 固件，SHA256：
   `649e372ab0289cc3cea933d485cdcbb3fd0c4d7b730e54de4203aec780c1848f`。
4. 基础 OpenWrt 启动后刷回已验证的 One-KVM sysupgrade，SHA256：
   `e517a986b96f9e6834345581cf9988340b8f21a0aab6ff1a694a4d59cda5fd47`。
5. 恢复刷机前 sysupgrade 备份。One-KVM 数据库恢复后 SHA256 与刷机前一致：
   `c4c5c8f16ebd72e6136956f6f0bd2f7c189716a87b5c612e1e8389b554a126de`。

恢复后 LuCI、SSH、One-KVM、四口 `br-lan`、MS2109 和 CH340 均正常，并确认
`/sys/class/udc` 为空。

## 变量分离

在稳定固件上仅临时设置 OpenWrt `packet_steering=2`，不执行 `uci commit`，
也不加载 PLL 模块。结果：

- `eth0` 和 `eth1` 共 64 个 RX 队列；
- 64 个 `rps_cpus` 全部为 `f`；
- SSH 连接和桥成员保持正常；
- UCI 变更在测试后撤销。

这证明 RPS 的基本运行路径可用，但不等于已完成 PXE 端口切换、LuCI
或长时间流量回归。

## 源码修正

- 取消 `kmod-airoha-an7581-oc` 的 `AUTOLOAD`。
- 默认 1200 MHz、恢复原厂和异常标记路径都不调用 `modprobe`。
- 只有用户明确确认 1300/1400 MHz 时才按需加载模块。
- 模块加载时遇到非 1200/1300/1400 MHz 回读会直接拒绝，不写 PLL。
- 模块卸载仅在确认当前为 1300/1400 MHz 时恢复 1200 MHz；异常读回不写 PLL。
- 新增回归测试，确保原厂启动、恢复原厂和异常标记路径都不加载模块。

## 修正版实机闭环

修正版在实机验证中继续发现并修复了两个仅影响“交换性能”页面的脚本问题：

- `jshn.sh` 会读取尚未建立的 JSON 状态变量，不能在整个 JSON 构造阶段保持
  shell `nounset`；现已只在该代码块内关闭 `nounset`，并增加回归测试。
- rpcd 将方法参数通过标准输入传给可执行对象；控制脚本现同时兼容标准输入和
  旧式第三参数，RPS 模式与 1200 MHz 恢复操作均已实机验证。

最终固件信息：

```text
project commit: d3b638bcda80c21529a338b4537312f905ab0774
xg040g-performance: 1.0.0-r5
sysupgrade bytes: 59167015
sysupgrade SHA256: f45abc721e1d83c375bf85a614693729e12b51496c7a2253b7b629f4527c0544
```

镜像通过 `SHA256SUMS.local` 和设备端 `sysupgrade -T` 后，以不带 `-n` 的
`sysupgrade` 保留配置刷入。设备约 81 秒恢复 SSH。DHCP 在中间一次启动中曾把
同一管理 MAC 分配到另一个地址，随后又回到原租约；以后应按稳定 hostname/MAC
发现设备，不能只凭旧 IPv4 地址判断启动失败。

最终运行结果：

- `br-lan` 包含 `lan2 lan3 lan4 eth1`，`PXE_PORT=none`，不存在 `br-pxe`；
- `network.globals.packet_steering=2`，`eth0`/`eth1` 共 64 个 RX 队列全部为
  RPS 掩码 `f`；状态 RPC 和参数化控制 RPC 均正常；
- 配置保持 `overclock=0`、`frequency=1200`，PLL 模块未加载、sysfs 不存在、
  `/etc/modules.d` 无自动加载项；“恢复原厂 1200 MHz”不会加载模块；
- `xg040g-cpuctl` 和 rpcd 脚本的运行文件与 `/rom` SHA256 完全一致，排除了
  overlay 热修复对结果的影响；
- One-KVM 数据库 SHA256 仍为
  `c4c5c8f16ebd72e6136956f6f0bd2f7c189716a87b5c612e1e8389b554a126de`；
- One-KVM RSS 约 20.7 MiB，`MemAvailable` 约 141 MiB，overlay 可用约
  164.1 MiB；实测温度约 75.8-76.6 摄氏度，低于 85 摄氏度回退阈值；
- MS2109 提供两个 V4L2 节点和 USB Audio，CH340 正常生成 `/dev/ttyUSB0`
  及 `/dev/ch9329`；四种 720p 软件编码器单帧测试全部通过。

本轮刻意没有加载 PLL 模块，也没有执行 1300/1400 MHz。可选超频压力测试、
动态 PXE 切换后的持续 RPS 流量以及 2.5G 多终端聚合吞吐仍是独立待测项。
