# 硬件与功能验证状态

更新时间：2026-07-10。

## 已验证

- `nokia_xg-040g-md-tcboot` factory/sysupgrade 构建成功并可启动。
- LuCI、uhttpd、Dropbear、保留配置 sysupgrade 正常。
- 两个 xHCI 控制器工作，系统显示四个 USB2/USB3 root hub。
- host-only 状态下 `/sys/class/udc` 为空。
- One-KVM 0.2.3 二进制和 `luci-app-one-kvm` 可安装并读取状态。
- PXE 独立网络、dnsmasq TFTP 与 uhttpd HTTP 文件路径曾在原型固件验证。
- 无 rclone 配置时 helper 能以明确错误退出，不影响本地 PXE 内容。

## 等待硬件

- MS2109 出现 `/dev/video0`、格式枚举和 One-KVM 实际视频流。
- CH340/CH341 + CH9329 的 `/dev/ch9329`、键盘与鼠标事件。
- USB3 外置盘 `KVMSTORE` 的 5 Gbit/s 链路、自动挂载与持续读写。
- WebDAV/rclone 实际 remote 同步。

## 不支持

- AN7581 USB gadget HID。
- AN7581 USB gadget mass-storage/虚拟光驱。
- 直接依赖实时 WebDAV mount 的 PXE 启动。

MTU3 D0/D1 实验在两个控制器上都读到零 endpoint capability，详细补丁与
结论保存在 `experiments/unsupported/`。

