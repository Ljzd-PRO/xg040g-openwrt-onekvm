# 硬件与功能验证状态

更新时间：2026-07-12。

## 已验证

- `nokia_xg-040g-md-tcboot` factory/sysupgrade 构建成功并可启动。
- LuCI、uhttpd、Dropbear、保留配置 sysupgrade 正常。
- 两个 xHCI 控制器工作，系统显示四个 USB2/USB3 root hub。
- host-only 状态下 `/sys/class/udc` 为空。
- One-KVM 0.2.3 完整运行时、LuCI 版本状态、默认停用和 ROM 恢复均已验证。
- MS2109 UVC 视频、USB Audio、One-KVM MJPEG/快照/Opus 音频链路已验证。
- CH340 + CH9329 `V3.8` 在 9600 baud 下完成键盘 LED 往返和相对鼠标测试。
- H.264、H.265、VP8、VP9 软件编码器均完成 720p 单帧烟测。
- PXE 独立网络、dnsmasq TFTP 与 uhttpd HTTP 文件传输已验证。
- rclone 本地 remote fixture 已验证 dry-run、缓存刷新和断源保留行为。
- 无 rclone 配置时 helper 能以明确错误退出，不影响本地 PXE 内容。
- 123 云盘 WebDAV 已通过 rclone 目录、上传、回读 SHA256、删除、1 GiB
  FirPE 下载以及 WinFsp 挂载读取测试。
- Hyper-V Generation 2 已经通过 LAN4 完成 DHCP、TFTP、iPXE、FirPE 网络
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

详细实测数据见 [2026-07-12 full-profile hardware validation](hardware-validation-20260712.md)
和 [2026-07-12 WebDAV/Hyper-V PXE validation](hardware-validation-20260712-webdav-hyperv-pxe.md)。

## 不支持

- AN7581 USB gadget HID。
- AN7581 USB gadget mass-storage/虚拟光驱。
- 直接依赖实时 WebDAV mount 的 PXE 启动。

MTU3 D0/D1 实验在两个控制器上都读到零 endpoint capability，详细补丁与
结论保存在 `experiments/unsupported/`。
