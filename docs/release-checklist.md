# Release checklist

## Source

- [x] 父仓库工作区干净。
- [x] 两个 submodule commit 与 `locks/sources.lock` 一致。
- [x] feeds 全部固定到 commit。
- [x] `./scripts/validate.sh` 通过。
- [x] 没有备份、Cookie、密码、token、私钥或用户绝对路径被跟踪。

## Build

- [x] `minimal` clean build 成功。
- [x] `onekvm` clean build 成功。
- [x] `onekvm --offline` 热缓存构建成功。
- [x] One-KVM 最终产物的 `SHA256SUMS.local` 通过。
- [x] manifest 必需包和禁止包检查通过。
- [x] sysupgrade 不超过 80 MiB，三个独立 APK 与 `APK-METADATA.json` 齐全。
- [ ] source-with-submodules bundle 能在独立目录初始化构建。

## Device smoke test

- [x] `sysupgrade -T` 成功。
- [x] 不带 `-n` 升级后密码、网络配置及 One-KVM 初始化数据保留。
- [x] 三分钟内恢复 LuCI 与 SSH。
- [x] 四个 xHCI root hub、空 UDC。
- [x] One-KVM 版本、LuCI RPC 和默认停用策略正确。
- [x] ttyd、GOSTC、EasyTier、FRPC、音频库和运行时 ABI 版本正确。
- [x] FRPC 标准 UCI/procd 文件、官方 LuCI 中文页面及 One-KVM 状态入口正常，
  默认未启动且未启用开机启动。
- [x] `one-kvm-codec-check` 的 H.264/H.265/VP8/VP9 单帧测试全部通过。
- [x] 无硬件启动烟测 RSS 小于 100 MiB，`MemAvailable` 不低于 64 MiB。
- [ ] 不同签名的无害 APK 可经 LuCI 本地上传安装，URL 安装策略未放宽。
- [x] 制造可逆 overlay 覆盖后，LuCI 恢复得到与 ROM 相同的 SHA256 和服务状态。
- [x] 默认 LAN2/LAN3/LAN4/2.5G 全部组成 `br-lan`，正常系统无 WAN，failsafe
  窗口为 12 秒。
- [x] 上游 DHCP、稳定 `.local` 与 15 秒 IPv4LL 后备均已闭环。
- [x] 默认四口全部属于 `br-lan`，未创建 `br-pxe` 且不提供 PXE DHCP。
- [x] 五种 PXE 端口配置通过自动化拓扑测试，单口隔离及可选单向 NAT 配置正确。
- [x] LAN4、LAN3、2.5G 的运行态切换、`none` 恢复、LAN4 重启持久化及 LuCI
  确认/取消流程已实机验证。
- [x] PXE 启用时 mDNS 只发布到 `br-lan`，不在 `br-pxe` 发布管理入口。
- [x] One-KVM 数据重置的取消、确认、目录保护与服务状态恢复均已验证。
- [ ] 默认 1200 MHz、超频锁关闭、PLL 回读及“恢复原厂频率”实机验证。
- [ ] `eth0`/`eth1` 共 64 个 RX 队列的全核 RPS 掩码已实机验证；PXE 切换后
  重载和 LuCI 状态仍待修正版固件验证。
- [ ] 1300/1400 MHz 各五分钟压力测试完成，并在测试后恢复 1200 MHz。

## Hardware promotion

- [x] MS2109 视频闭环。
- [x] CH9329 键鼠闭环。
- [ ] USB3 KVMSTORE 闭环。
- [ ] 动态选择的 PXE 端口完成 UEFI/BIOS、FirPE 与 SystemRescue 再验证；旧固定
  LAN4 固件上的启动链路已经闭环。
- [x] rclone/WebDAV 真实读写、完整下载与挂载读取闭环。

硬件闭环未全部完成时，Release 必须保持 prerelease。
