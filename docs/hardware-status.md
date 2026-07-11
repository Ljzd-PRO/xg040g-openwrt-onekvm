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

## 已延期或等待外部条件

- USB3 外置盘 `KVMSTORE` 的 5 Gbit/s 链路、自动挂载与持续读写。
- 物理 PXE 客户端的 DHCP、iPXE 执行和系统启动。
- 真实 WebDAV/rclone remote 的鉴权和同步。
- 实体 ATX 继电器后端。

详细实测数据见 [2026-07-12 full-profile hardware validation](hardware-validation-20260712.md)。

## 不支持

- AN7581 USB gadget HID。
- AN7581 USB gadget mass-storage/虚拟光驱。
- 直接依赖实时 WebDAV mount 的 PXE 启动。

MTU3 D0/D1 实验在两个控制器上都读到零 endpoint capability，详细补丁与
结论保存在 `experiments/unsupported/`。
