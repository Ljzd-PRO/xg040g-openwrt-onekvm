# 硬件与功能验证状态

更新时间：2026-07-14。

## 已验证

- `nokia_xg-040g-md-tcboot` factory/sysupgrade 构建成功并可启动。
- LuCI、uhttpd、Dropbear、保留配置 sysupgrade 正常。
- LuCI Statistics、collectd CPU/内存/负载/接口统计和 AN7581 `cpu-thermal`
  温度 RRD 已完成保留配置刷机与实机图表验证。
- 最终性能固件已在实机确认 `eth0`/`eth1` 共 64 个 RX 队列的全核 RPS 掩码
  全为 `f`；持久配置、LuCI 状态 RPC 和参数化控制 RPC 均正常，SSH 与四口
  `br-lan` 保持可用。
- 首个性能实验固件在保留配置刷入后失去管理网络，已通过 tcboot、稳定
  固件和刷机前备份完整恢复。由于 factory 重建 overlay 后无法保留失败启动日志，
  不对根因作无证据结论；最终 `xg040g-performance 1.0.0-r5` 已完成无超频
  保留配置刷机，默认 1200 MHz、恢复原厂和 RPS 控制路径均不加载 PLL 模块。
- 两个 xHCI 控制器工作，系统显示四个 USB2/USB3 root hub。
- host-only 状态下 `/sys/class/udc` 为空。
- One-KVM 0.2.3 完整运行时、LuCI 版本状态、默认停用和 ROM 恢复均已验证。
- FRPC 0.69.1 标准 UCI/procd 服务、官方 LuCI 中文配置页、One-KVM 状态与
  跳转入口已完成保留配置刷机和实机验证；FRPC 默认保持停用。
- MS2109 UVC 视频、USB Audio、One-KVM MJPEG/快照/Opus 音频链路已验证。
- CH340 + CH9329 `V3.8` 在 9600 baud 下完成键盘 LED 往返和相对鼠标测试。
- H.264、H.265、VP8、VP9 软件编码器均完成 720p 单帧烟测。
- PXE 独立网络、dnsmasq TFTP 与 uhttpd HTTP 文件传输已验证。
- 默认四口交换机和持久化 PXE 端口选择已验证；LAN3、LAN4、2.5G 均完成
  运行态切换，LAN4 完成重启持久化，`none` 可恢复四口 `br-lan`。
- rclone 本地 remote fixture 已验证 dry-run、缓存刷新和断源保留行为。
- 无 rclone 配置时 helper 能以明确错误退出，不影响本地 PXE 内容。
- 123 云盘 WebDAV 已通过 rclone 目录、上传、回读 SHA256、删除、1 GiB
  FirPE 下载以及 WinFsp 挂载读取测试。
- 旧固定 LAN4 拓扑下，Hyper-V Generation 2 已经完成 DHCP、TFTP、iPXE、FirPE 网络
  与离线模式、SystemRescue root shell 全链路；Generation 1 已进入同一
  iPXE 菜单。
- PXE 默认隔离已从 SystemRescue 实测：本地启动 HTTP 可达，设备管理端口
  和上游网络不可达。
- Cloud PXE LuCI RPC、只读 rclone HTTP 8083、selector 切换及清除恢复已完成
  实机闭环；见 [Cloud PXE firmware validation](hardware-validation-20260712-cloud-pxe.md)。

## 已延期或等待外部条件

- USB3 外置盘 `KVMSTORE` 的 5 Gbit/s 链路、自动挂载与持续读写。
- 实体 ATX 继电器后端。
- Cloud PXE 从真实远程存储启动 FirPE/SystemRescue 的双网线复测。
- 2.5G 主机同时向两个或三个千兆终端转发的聚合吞吐和 24 小时稳定性测试。

详细实测数据见 [2026-07-12 full-profile hardware validation](hardware-validation-20260712.md)
、[2026-07-12 WebDAV/Hyper-V PXE validation](hardware-validation-20260712-webdav-hyperv-pxe.md)
和 [2026-07-13 monitoring validation](hardware-validation-20260713-monitoring.md)。
FRPC 独立管理的本轮结果见
[2026-07-13 FRPC validation](hardware-validation-20260713-frpc.md)。持久化 PXE
端口切换见 [2026-07-13 PXE port v2 validation](hardware-validation-20260713-pxe-port-v2.md)。
性能固件恢复与安全收敛记录见
[2026-07-14 performance recovery](hardware-validation-20260714-performance-recovery.md)。

## 不支持

- AN7581 USB gadget HID。
- AN7581 USB gadget mass-storage/虚拟光驱。
- 直接依赖实时 WebDAV mount 的 PXE 启动。

MTU3 D0/D1 实验在两个控制器上都读到零 endpoint capability，详细补丁与
结论保存在 `experiments/unsupported/`。
