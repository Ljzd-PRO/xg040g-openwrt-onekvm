# XG-040G-MD OpenWrt One-KVM

这是一个非官方的 Nokia XG-040G-MD OpenWrt 构建仓库，提供固定源码版本、
Docker 构建环境、GitHub Actions、原生 One-KVM 包和 LuCI 管理页面。

本项目采用 USB host-only 路线：MS2109 负责 UVC HDMI 采集，
CH340/CH341 + CH9329 负责键鼠模拟，安装镜像通过 PXE、USB3 外置存储和
rclone/WebDAV 缓存提供。AN7581 UDC/OTG 不在受支持功能中。

## 状态

| 项目 | 状态 |
| --- | --- |
| tcboot OpenWrt、LuCI、SSH | 已验证 |
| 两个 xHCI 控制器、四个 USB root hub | 已验证 |
| 原生 One-KVM 0.2.3 与 LuCI 包安装 | 已验证 |
| MTU3/UDC gadget endpoint | 不支持，实验结果为零 endpoint |
| MS2109 视频采集 | 等待硬件验证 |
| CH9329 键鼠控制 | 等待硬件验证 |
| USB3 `KVMSTORE` 外置盘 | 等待硬件验证 |

在后三项完成闭环前，自动发布的固件均标记为 prerelease。

## 固件配置

- `minimal`：LuCI、SSH、USB3、UBI 与 U-Boot 环境工具，适合首次验证和恢复。
- `onekvm`：在 minimal 基础上加入 One-KVM、LuCI 管理、UVC、CH9329、
  USB3 存储、PXE/iPXE、rclone/WebDAV 支持。

两种配置均为 host-only，不包含 `kmod-usb-mtu3` 或 USB gadget 包。

## 快速构建

建议准备 Docker、Git、至少 40 GiB 可用磁盘和 8 GiB 内存。macOS、Linux
以及带 Docker Desktop 的 WSL2 均可使用。

```bash
git clone --recurse-submodules --shallow-submodules \
  https://github.com/Ljzd-PRO/xg040g-openwrt-onekvm.git
cd xg040g-openwrt-onekvm
./scripts/build.sh onekvm --jobs 10
```

如果普通 clone 时没有下载 submodule，`build.sh` 会自动初始化并 checkout
父仓库记录的精确 commit。

```bash
./scripts/build.sh minimal
./scripts/build.sh onekvm
```

默认 `isolated` 模式从 submodule 建立本地、无网络的 Docker 工作副本。
Linux 还可使用 `--source-mode direct` 直接在 OpenWrt submodule 中构建；
macOS 默认文件系统大小写不敏感，因此必须使用 isolated 模式。

更完整的参数和缓存说明见 [构建文档](docs/build.md)。

## 源码锁定

- OpenWrt：`4984eff3c34a5b8d7995e2b2a0a3823bba31c1fc`
- One-KVM：`7753c83e27d20ba31d19daafdddedada7e89e32c`
  (`v260626`, `0.2.3`)
- OpenWrt feeds：见 `locks/feeds.conf`

GitHub 自动生成的 Source code ZIP 不包含 submodule 内容。请使用 Git clone，
或下载 Release 中的 `source-with-submodules.tar.zst`。

## 刷机

- 已运行本项目 tcboot OpenWrt：使用 `*-sysupgrade.bin`。
- tcboot/Web U-Boot 首刷：使用 `*-factory.bin`。
- `initramfs.itb` 仅用于临时启动和诊断。

项目不分发来源与再分发许可不明确的 `tcboot.bin`，也不会包含设备密码、
Cookie 或原厂备份。具体流程和参考资料见 [刷机文档](docs/flashing.md)。

## One-KVM 运行方式

One-KVM 默认监听 `8080`，但服务默认关闭，避免未连接采集卡和 CH9329 时
反复重启。诊断用 ustreamer 默认关闭，启用后使用 `8081`。

```bash
uci set one-kvm.main.enabled='1'
uci commit one-kvm
/etc/init.d/one-kvm restart
```

LuCI 入口为“服务 -> One-KVM”。

## 上游与许可证

- [OpenWrt](https://github.com/openwrt/openwrt)
- [One-KVM](https://github.com/mofeng-git/One-KVM)
- [OpenWrt XG-040G-MD 初始支持提交](https://github.com/openwrt/openwrt/commit/a6ecb09985fa7c14bae1c1bad7d42495737bc0ba)

本仓库默认代码与 One-KVM 补丁采用 GPL-3.0-only；LuCI 应用采用
Apache-2.0。submodule 保留各自上游许可证。详见 `LICENSES/`。
