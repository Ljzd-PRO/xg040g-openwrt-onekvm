# One-KVM 完整运行时

`onekvm` profile 面向 XG-040G-MD 的 host-only 使用方式。它不尝试模拟 USB
device，也不提供 USB 虚拟光驱；安装介质由本地 USB3 `KVMSTORE`、PXE/iPXE
和 rclone/WebDAV 下行缓存提供。

## 功能闭包

- 视频：V4L2/UVC、MS2109、libjpeg-turbo、真实 libyuv。
- 音频：USB Audio、ALSA 工具和库、Opus。
- 软件编码：FFmpeg 6.1.4、libx264、libx265、libvpx VP8/VP9。
- 键鼠：CH340/CH341 + CH9329、ACM、CP210x、FTDI、PL2303、hidraw。
- ATX：GPIO character device、串口/HID relay 和 Wake-on-LAN 依赖。
- 扩展：ttyd 1.7.7、GOSTC 2.0.9、EasyTier 2.4.5、FRPC 0.69.1、TUN 和 Bash。
- 存储与启动：USB3/UAS/ext4、PXE/iPXE、HTTP、rclone/WebDAV。

`xg040g-onekvm-runtime` 元包固定这组依赖，并在
`/usr/share/xg040g-onekvm-runtime/abi` 记录 ABI 标记。GOSTC 与 EasyTier 使用
固定版本的 AArch64 静态发行文件，构建时同时校验下载 SHA256、ELF 架构和静态
链接属性。

AN7581 没有本项目可用的硬件编码驱动。H.264、H.265、VP8 和 VP9 均为软件
编码；`one-kvm-codec-check` 只用一帧 720p 验证编码器可初始化，不代表设备能
实时完成 1080p、2K 或 4K 编码。

CH9329 默认使用兼容出厂设置的 9600 波特率。确认串口握手正常后，可用 WCH
配置工具把芯片改为 115200，并在 LuCI 中同步修改，以降低键鼠延迟。

## 默认状态

One-KVM 主服务默认关闭。ttyd、GOSTC、EasyTier 和 FRPC 不运行独立的 procd
实例，由 One-KVM 在用户配置对应扩展后统一管理。音频、软件编码和 ATX 后端
只提供依赖，不会在无硬件时主动工作。

host-only 适配会拒绝 OTG/MSD 设置，并隐藏 WebUI 中不可用的虚拟介质入口。
RustDesk、VNC 和 RTSP 继续使用 One-KVM 自带实现，不额外启动外部远程桌面
守护进程。

## APK 与升级

One-KVM 上游的版本检查、下载按钮和更新逻辑不做修改。上游更新写入 overlay
后，LuCI 的版本表会显示运行文件是否与 `/rom/usr/bin/one-kvm` 不同。

“恢复固件内置程序”会停止 One-KVM，把 ROM 二进制复制到同目录临时文件，
校验 SHA256 后用 `mv` 原子替换，再清理已知升级残留；只有服务原本启用时才会
重新启动。它不会删除 `/usr/bin/one-kvm`，也不会直接修改
`/overlay/upper`，因此不会制造 overlay whiteout。

Release 独立提供以下 APK：

- `one-kvm`
- `luci-app-one-kvm`
- `luci-i18n-one-kvm-zh-cn`

LuCI 软件包页面只对上传后固定位置 `/tmp/upload.apk` 的本地 APK 安装追加
`--allow-untrusted`；URL 和仓库安装仍要求正常签名。独立 APK 依赖完整版固件
提供的 `xg040g-onekvm-runtime` ABI，不支持直接安装到旧版或 minimal 固件。

`/etc/config/one-kvm` 和整个 `/etc/one-kvm/` 都列入 sysupgrade/包升级保留
范围。APK 升级完成后，也只有服务原本启用时才自动重启。

## 数据重置与 PXE 上游

LuCI One-KVM 页面提供“重置 One-KVM 数据”。操作前必须勾选警告确认，RPC
还要求固定确认值 `RESET`。它只删除并以 `0700` 重建真实目录
`/etc/one-kvm`，会清除登录账号、数据库、会话、证书、内部设置和更新缓存；
不会删除 `/etc/config/one-kvm`、ROM 程序、KVMSTORE、PXE 文件或 rclone
配置。目录是符号链接或 One-KVM 使用自定义数据目录时，重置会被拒绝。

同一页面还可控制 LAN4 PXE 客户端的上游访问。默认关闭，只允许本地
DHCP/TFTP/HTTP；开启后创建单向 `pxe -> lan` 转发并在管理出口做 NAT，
不会开放上游到 PXE 子网或 PXE 到设备管理端口的访问。
