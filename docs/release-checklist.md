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
- [ ] 两套 `SHA256SUMS.local` 通过。
- [ ] manifest 必需包和禁止包检查通过。
- [ ] source-with-submodules bundle 能在独立目录初始化构建。

## Device smoke test

- [ ] `sysupgrade -T` 成功。
- [ ] 不带 `-n` 升级后密码与网络配置保留。
- [ ] 三分钟内恢复 LuCI 与 SSH。
- [ ] 四个 xHCI root hub、空 UDC。
- [ ] One-KVM 版本、LuCI RPC 和默认停用状态正确。

## Hardware promotion

- [ ] MS2109 视频闭环。
- [ ] CH9329 键鼠闭环。
- [ ] USB3 KVMSTORE 与 PXE 闭环。
- [ ] rclone/WebDAV 同步闭环。

硬件闭环未全部完成时，Release 必须保持 prerelease。

