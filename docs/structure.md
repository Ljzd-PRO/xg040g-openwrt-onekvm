# 仓库结构与维护指南

本文面向后续继续开发、复现构建和维护发布。日常使用者可以先看
`README.md` 和 `docs/build.md`；需要改配置、包、CI 或上游版本时再看本文。

## 顶层目录

| 路径 | 用途 | 是否提交 |
| --- | --- | --- |
| `.github/` | GitHub Actions、Dependabot 配置。 | 是 |
| `configs/` | OpenWrt defconfig。`minimal.config` 用于基础固件，`onekvm.config` 用于 One-KVM 固件。 | 是 |
| `docker/` | 固定构建容器，包含 OpenWrt、Go、Node.js、Rust 所需工具。 | 是 |
| `docs/` | 构建、刷机、硬件状态、发布和维护文档。 | 是 |
| `experiments/unsupported/` | 已归档的 AN7581 MTU3/UDC 实验补丁和结论。仅作审计与参考。 | 是 |
| `locks/` | 上游源码和 feeds 的固定版本。 | 是 |
| `package/` | 本项目维护的 OpenWrt 本地包。 | 是 |
| `scripts/` | bootstrap、构建、校验、打包和 source bundle 脚本。 | 是 |
| `upstream/openwrt` | OpenWrt submodule，固定到 `locks/sources.lock` 中的 commit。 | gitlink |
| `upstream/one-kvm` | One-KVM submodule，固定到 `locks/sources.lock` 中的 commit。 | gitlink |
| `.cache/` | 下载缓存和 feed bare repo 缓存。可删除。 | 否 |
| `output/` | 本地构建输出和日志。可删除或归档到仓库外。 | 否 |
| `dist/` | 本地生成的 source bundle 或临时发布包。 | 否 |

不要把父级工作目录中的 `downloads/`、`session-pages/`、`tmp-web/`、原厂备份、
`tcboot.bin`、cookie、私钥、`rclone.conf` 或设备密码复制进这个仓库。
`./scripts/validate.sh` 会检查一部分常见误提交。

## 核心文件

| 文件 | 说明 |
| --- | --- |
| `.gitmodules` | 声明 OpenWrt 与 One-KVM submodule URL。 |
| `.gitignore` | 阻止缓存、固件产物、本地凭据和设备采集材料进入仓库。 |
| `locks/sources.lock` | 锁定 submodule path、URL、commit 和版本备注。 |
| `locks/feeds.conf` | 锁定 OpenWrt feeds 的 commit。 |
| `scripts/bootstrap.sh` | 初始化 submodule，并校验实际 checkout 是否与 `sources.lock` 一致。 |
| `scripts/build.sh` | 主构建入口。默认 isolated 模式，不直接污染 OpenWrt submodule。 |
| `scripts/validate.sh` | 仓库一致性、脚本语法、patch dry-run、配置和 Dockerfile 检查。 |
| `scripts/verify-output.sh` | 检查构建产物、manifest 必需包和禁止包。 |
| `scripts/package-release.sh` | 把 build output 规范化成 Release asset 名称。 |
| `scripts/create-source-bundle.sh` | 生成包含 submodule 内容的源码归档。 |
| `scripts/hyperv-pxe-lab.ps1` | 创建、检查或清理隔离的 Hyper-V PXE 验证环境。 |
| `scripts/prepare-firpe-ipxe-assets.ps1` | 获取并校验固定版本的 wimboot 与 PXEBCD。 |
| `scripts/build-ipxe-embedded.sh` | 构建带固定 chain 脚本的 UEFI/BIOS iPXE。 |
| `scripts/test-pxe-port-topology.sh` | 验证关闭 PXE 及四个单口选择的桥、DHCP 与防火墙拓扑。 |

## 本地包布局

| 路径 | 说明 |
| --- | --- |
| `package/one-kvm/` | One-KVM 原生 OpenWrt 包。Makefile 从固定 submodule 生成源码包并应用补丁。 |
| `package/one-kvm/patches/` | One-KVM 适配 OpenWrt/AN7581 的补丁。更新 One-KVM 时必须重新验证。 |
| `package/one-kvm/files/` | UCI 默认配置、init 脚本、硬件检查脚本和锁定的 `Cargo.lock`。 |
| `package/luci-app-one-kvm/` | LuCI 管理界面、rpcd ACL、ucode RPC 和中文翻译。 |
| `package/xg040g-onekvm-runtime/` | 完整运行时元包、ABI 标记和依赖所有权检查。 |
| `package/libffmpeg-onekvm/` | 只包含 One-KVM 所需解码/软件编码器的 FFmpeg 库与 codec check。 |
| `package/libyuv/`、`package/libx265/` | 固定版本的本地多媒体依赖。 |
| `package/gostc/`、`package/easytier-core/` | 固定哈希和 ELF 属性检查的 AArch64 扩展程序。 |
| `package/xg040g-kvm-support/` | host-only KVM-lite 辅助脚本：UVC、CH9329、PXE/rclone helper 等。 |
| `package/xg040g-switch-management/` | DHCP 管理交换桥、IPv4LL/mDNS、持久化 PXE 端口选择、网络迁移与恢复 helper。 |
| `package/xg040g-monitoring-defaults/` | LuCI/collectd 统计与 AN7581 温度采集默认配置。 |
| `package/kmod-airoha-an7581-oc/` | 仅限 tcboot 机型、不自动加载、加载时不改频的 AN7581 PLL 模块。 |
| `package/xg040g-performance/` | 默认 1200 MHz 的 CPU 策略、温控回退、RPS 状态与 RPC。 |
| `package/luci-app-xg040g-performance/` | “系统 -> 交换性能”页面及简体中文翻译。 |
| `patches/openwrt/common/` | 两个 profile 共用的 XG-040G-MD 默认交换机/PXE 源码补丁。 |
| `patches/luci/common/` | 两个 profile 共用的 LuCI 状态页兼容与显示修复。 |
| `patches/*/onekvm/` | 仅完整版 profile 应用的 OpenWrt、feeds 与 LuCI 兼容补丁。 |

One-KVM 包不要直接软链到 `upstream/one-kvm`。OpenWrt 的标准流程需要在临时
build tree 中 unpack、patch 和 build，submodule 应保持只读和干净。

## 常见开发任务

### 改固件包选择

修改 `configs/minimal.config` 或 `configs/onekvm.config`，然后运行：

```bash
./scripts/validate.sh
./scripts/build.sh minimal --jobs 10
./scripts/build.sh onekvm --jobs 10
```

新增本地包后，还要确认 `scripts/verify-output.sh` 中的 manifest 检查是否需要
同步更新。

### 改 One-KVM 包

通常涉及：

- `package/one-kvm/Makefile`
- `package/one-kvm/patches/*.patch`
- `package/one-kvm/files/*`
- 必要时更新 `package/one-kvm/files/Cargo.lock`

先运行 `./scripts/validate.sh`，它会把 One-KVM submodule archive 到临时目录，
并 dry-run/应用全部 patch。

### 改 LuCI 管理界面

主要路径：

- `package/luci-app-one-kvm/htdocs/luci-static/resources/view/one-kvm/general.js`
- `package/luci-app-one-kvm/root/usr/share/rpcd/ucode/one-kvm.uc`
- `package/luci-app-one-kvm/root/usr/share/luci/menu.d/`
- `package/luci-app-one-kvm/root/usr/share/rpcd/acl.d/`
- `package/luci-app-one-kvm/po/zh_Hans/one-kvm.po`

至少运行 `./scripts/validate.sh`。涉及运行态行为时，需要刷机后在 LuCI 和
`ubus call luci.one-kvm status` 上做烟测。

版本和恢复逻辑还涉及：

- `package/luci-app-one-kvm/root/usr/sbin/one-kvm-restore-firmware`
- `package/luci-app-one-kvm/root/usr/share/rpcd/ucode/one-kvm.uc`

恢复测试必须验证 ROM/运行文件 SHA256、服务原状态和 overlay 状态，不能直接
删除 `/usr/bin/one-kvm` 或修改已挂载的 `/overlay/upper`。

### 改 PXE、rclone、CH9329、ustreamer helper

主要路径是 `package/xg040g-kvm-support/`。注意：

- 默认不要写入任何云端账号、token、WebDAV URL 或密码。
- CH9329 未到货前不要默认启用会发送键鼠事件的服务。
- PXE 默认读取本地 `/mnt/kvmstore`，不要让启动链路依赖实时 WebDAV mount。
- 修改 shell 脚本后运行 `./scripts/validate.sh`；CI 有 shellcheck，会暴露本地
  未安装 shellcheck 时看不到的问题。

### 更新 OpenWrt

一次只移动 OpenWrt：

```bash
git -C upstream/openwrt fetch origin NEW_COMMIT
git -C upstream/openwrt checkout --detach NEW_COMMIT
```

然后同步更新 `locks/sources.lock` 中 OpenWrt 行，构建 `minimal` 和 `onekvm`，
并做实机升级烟测。OpenWrt gitlink 与 `sources.lock` 应放在同一个
`build(deps): ...` 提交里。

### 更新 One-KVM

一次只移动 One-KVM。更新后通常还要：

- 调整 `package/one-kvm/Makefile` 的版本和源码 SHA256。
- 重新生成并检查 `package/one-kvm/files/Cargo.lock`。
- 重新验证 `package/one-kvm/patches/` 是否仍可应用。
- 构建 `onekvm` profile 并实机验证 One-KVM 启动、LuCI 状态和日志。

One-KVM gitlink、包 hash、Cargo.lock 和补丁适配应拆成清晰的 package/build
提交，不要和 OpenWrt 更新混在一起。

### 改 CI 或发布流程

主要路径：

- `.github/workflows/validate.yml`
- `.github/workflows/firmware.yml`
- `.github/workflows/release.yml`
- `.github/dependabot.yml`
- `scripts/package-release.sh`
- `scripts/create-source-bundle.sh`

注意 `firmware.yml` 对 `main` 使用 concurrency。同一分支的新 push 会取消正在
运行的固件构建。若主线构建已经跑很久，文档或小修可以先本地提交，等构建结束
后再推送。

## 标准检查顺序

本地改动完成后建议按这个顺序：

```bash
git status -sb
./scripts/validate.sh
./scripts/build.sh minimal --jobs 10
./scripts/build.sh onekvm --jobs 10
```

如果只是文档改动，通常 `./scripts/validate.sh` 足够。发布固件前必须 clean build
目标 profile，并检查 `output/<profile>/SHA256SUMS.local`、manifest、
`BUILD-METADATA.json` 和 `APK-METADATA.json`。完整版还应执行一次热缓存
`--offline` 构建，证明 Cargo/npm/feed 依赖可离线复用。

## 提交与推送

保持提交按目的拆分：

- `docs`: 文档。
- `build`: 构建脚本、Docker、发布工具。
- `build(deps)`: submodule、feeds、工具链或 Action 固定版本。
- `package`: OpenWrt 包和运行态脚本。
- `luci`: LuCI 页面、RPC、菜单和翻译。
- `ci`: GitHub Actions 结构变化。
- `experiments`: 不再支持但需要保留的实验补丁或报告。

推送前确认：

```bash
git status -sb
git submodule status --recursive
./scripts/validate.sh
```

如果要触发 prerelease，先在 GitHub Actions 手动运行 `Build firmware`，选择
`profile=all`。两个 profile 和 source bundle 均成功后，再运行
`Release firmware`，填写版本、前一步的 run ID，并保持 `prerelease=true`。
发布说明必须预先提交到：

```text
docs/releases/vYYYY.MM.DD-rc1.md
```

Release workflow 会确认构建与发布 commit 相同、三个 artifact 齐全且校验值通过，
然后创建 tag。不要再手动推送发布 tag。硬件闭环未完成前，Release 保持
prerelease。

## 故障排查提示

- `submodule commit mismatch`：运行 `./scripts/bootstrap.sh`，或检查
  `locks/sources.lock`、gitlink 和实际 checkout 是否一致。
- `Tracked changes found in submodule`：不要直接在 submodule 中开发；需要临时
  调试时用 `--allow-dirty`，正式提交前还原或形成上游补丁。
- CI 中 shellcheck 失败、本地没失败：本地可能没装 shellcheck。按 CI 日志修。
- `--source-mode direct` 被拒绝：两个 profile 都依赖只应用到一次性工作树的
  公共补丁，使用默认 isolated 模式。
- GitHub Source ZIP 不能复现：它不包含 submodule 内容。使用
  `git clone --recurse-submodules` 或 Release 的 `source-with-submodules.tar.zst`。
