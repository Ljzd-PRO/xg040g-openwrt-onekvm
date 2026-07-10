# Release checklist

## Source

- [ ] 父仓库工作区干净。
- [ ] 两个 submodule commit 与 `locks/sources.lock` 一致。
- [ ] feeds 全部固定到 commit。
- [ ] `./scripts/validate.sh` 通过。
- [ ] 没有备份、Cookie、密码、token、私钥或用户绝对路径被跟踪。

## Build

- [ ] `minimal` clean build 成功。
- [ ] `onekvm` clean build 成功。
- [ ] `onekvm --offline` 热缓存构建成功。
- [ ] 两套 `SHA256SUMS.local` 通过。
- [ ] manifest 必需包和禁止包检查通过。
- [ ] sysupgrade 不超过 80 MiB，三个独立 APK 与 `APK-METADATA.json` 齐全。
- [ ] source-with-submodules bundle 能在独立目录初始化构建。

## Device smoke test

- [ ] `sysupgrade -T` 成功。
- [ ] 不带 `-n` 升级后密码与网络配置保留。
- [ ] 三分钟内恢复 LuCI 与 SSH。
- [ ] 四个 xHCI root hub、空 UDC。
- [ ] One-KVM 版本、LuCI RPC 和默认停用状态正确。
- [ ] ttyd、GOSTC、EasyTier、FRPC、音频库和运行时 ABI 版本正确。
- [ ] `one-kvm-codec-check` 的 H.264/H.265/VP8/VP9 单帧测试全部通过。
- [ ] 无硬件启动烟测 RSS 小于 100 MiB，`MemAvailable` 不低于 64 MiB。
- [ ] 不同签名的无害 APK 可经 LuCI 本地上传安装，URL 安装策略未放宽。
- [ ] 制造可逆 overlay 覆盖后，LuCI 恢复得到与 ROM 相同的 SHA256 和服务状态。

## Hardware promotion

- [ ] MS2109 视频闭环。
- [ ] CH9329 键鼠闭环。
- [ ] USB3 KVMSTORE 与 PXE 闭环。
- [ ] rclone/WebDAV 同步闭环。

硬件闭环未全部完成时，Release 必须保持 prerelease。
