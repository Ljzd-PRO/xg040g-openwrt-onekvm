# FRPC LuCI 与保留配置刷机验证

验证日期：2026-07-13。

## 构建产物

- profile：`onekvm`
- 输出目录：`output/onekvm-frpc-luci-20260713`
- sysupgrade 大小：`59,156,775` 字节（约 56.4 MiB）
- sysupgrade SHA256：
  `add67c6dd70c7a7582cf46ce454f156b669ef261607c3813608f78be9448c8c5`
- 构建耗时：10 分 20.63 秒，exit status `0`
- manifest：`frpc 0.69.1-r1`、`luci-app-frpc`、
  `luci-i18n-frpc-zh-cn`、`luci-app-one-kvm 20260710-r8`

`scripts/verify-output.sh`、镜像 SHA256、三个独立 One-KVM APK 及构建元数据
校验全部通过。

## 刷机与服务

- 远端 SHA256 与本地一致，`sysupgrade -T` 通过。
- 使用不带 `-n` 的 `sysupgrade`，设备约一分钟内恢复 SSH。
- root 密码、One-KVM 初始化数据和既有配置均被保留。
- `/etc/config/frpc`、`/etc/init.d/frpc`、LuCI view 和 menu 文件均存在。
- `frpc --version` 返回 `0.69.1`。
- 默认状态为停止且未启用开机启动。
- 手动启动能够生成 `/var/etc/frpc.ini` 并完成配置解析；默认示例地址
  `127.0.0.1:7000` 无 FRPS，连接被拒绝后正常退出。测试后服务保持停止。

## LuCI

- “服务 -> frp 客户端”加载官方中文配置页面。
- One-KVM 状态表显示 FRPC 安装、运行和开机启动状态。
- “打开 FRPC 管理”可进入标准 FRPC LuCI 页面。
- RPC 在组件缺失时能区分二进制、LuCI、配置和 init 文件，并让入口显示相应
  提示。

保留配置升级后的旧浏览器 origin 曾命中刷机前的静态 JavaScript 缓存；使用
全新 origin 验证页面正常。README 已说明可用 `Ctrl+F5` 或隐私窗口刷新。

## 回归结果

- One-KVM、collectd、uhttpd 均运行。
- One-KVM RSS 为 `19,864 kB`，系统 `MemAvailable` 为约 148 MiB。
- `one-kvm-codec-check` 的 H.264、H.265、VP8、VP9 全部通过。
- 两个 xHCI 控制器仍显示四个 USB root hub，`/sys/class/udc` 为空。
- PXE 接口仍为 `10.40.0.1/24`；本轮未连接第二根管理网线，`lan` DHCP pending
  属于当前接线预期。
- overlay 可用约 164.1 MiB，CPU 温度采样正常。
