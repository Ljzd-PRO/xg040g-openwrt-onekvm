# 构建说明

## 环境

- Git 2.28 或更高版本
- Docker Desktop 或 Docker Engine
- 40 GiB 以上可用磁盘
- `minimal` 建议 8 GiB 内存；arm64 主机上的 `onekvm` 完整构建建议给 Docker
  Desktop 分配 16 GiB 内存
- macOS arm64、Linux amd64/arm64 或 WSL2

Docker 镜像固定 Go、Node.js、Rust 版本，并支持 amd64 与 arm64 host。
OpenWrt 最终目标始终是 `airoha/an7581`、`aarch64_cortex-a53`。

## 获取源码

```bash
git clone --recurse-submodules --shallow-submodules REPOSITORY_URL
cd xg040g-openwrt-onekvm
./scripts/bootstrap.sh --offline
```

最后一条命令验证两个 submodule 是否与 `locks/sources.lock` 一致。
普通 clone 也可以，首次运行 `build.sh` 时会自动初始化 submodule。

构建脚本永远 checkout 父仓库记录的 gitlink，不执行
`git submodule update --remote`。

## 构建命令

```bash
./scripts/build.sh minimal --jobs 10
./scripts/build.sh onekvm --jobs 10
```

常用参数：

- `--output PATH`：指定产物目录。
- `--jobs N`：并行任务数。
- `--incremental`：保留 build/staging 目录，仅限本地开发。
- `--source-mode isolated`：默认且唯一受支持的模式，在 Docker volume 中建立
  本地源码副本并应用公共/profile 补丁。
- `--offline`：禁止获取缺失 submodule 或 feed commit；包源码也必须已缓存。
- `--allow-dirty`：允许修改后的 submodule，仅限本地调试。

正式构建不得使用 `--incremental` 或 `--allow-dirty`。

完整 profile 会编译 FRP Web 资源、Rust 后端、One-KVM 前端和四种软件编码
依赖，第一次构建明显慢于 minimal。开发时可复用缓存：

```bash
./scripts/build.sh onekvm --jobs 10 --incremental
./scripts/build.sh onekvm --jobs 10 --incremental --offline
```

第二条命令也是缓存完整性测试：submodule、feed commit、源码包、Cargo crates
和 npm 包必须都已在本机缓存。仅当固定 tag 的 builder image 已存在时，可设置
`SKIP_BUILDER_BUILD=1` 跳过 Docker 镜像检查阶段。

构建日志默认使用 OpenWrt 的 `V=s`。排查编译或链接问题时可以临时增加
详细程度，例如：

```bash
BUILD_VERBOSITY=sc ./scripts/build.sh onekvm --jobs 1 --incremental
```

允许值为 `s`、`sc` 和 `c`；正式发布无需设置该环境变量。

## One-KVM 本地源码

仓库构建时，脚本从固定的 `upstream/one-kvm` gitlink 生成确定性的
`one-kvm-0.2.3.tar.gz`，写入 `.cache/dl`，并由包 Makefile 校验 SHA256。
OpenWrt 随后走标准 unpack/patch 流程，因此 submodule 本身不会被修改，全部
兼容补丁也会真实应用到 disposable build tree。

两个 profile 都会应用 `patches/openwrt/common/`。`onekvm` profile 还会按
顺序应用 `patches/openwrt/onekvm/`、
`patches/packages/onekvm/` 和 `patches/luci/onekvm/`。这些补丁只进入隔离构建
树，不会改动 submodule 或固定 feeds；`minimal` 不应用它们。

包中还带有从该固定 commit 与补丁集生成的 `Cargo.lock`。Rust 构建使用
`--locked`，避免 crates.io 的兼容版本在未来漂移。没有把 `PKG_BUILD_DIR`
软链到 submodule，因为 quilt/patch 阶段必须修改临时源码。

## 缓存与产物

- `.cache/dl`：OpenWrt 下载缓存，可以安全删除。
- `.cache/feeds`：固定 feed commit 的 bare Git 缓存，可以安全删除。
- Docker named volume：默认 isolated 工作目录。
- `output/<profile>-<timestamp>`：固件、独立 APK、manifest、buildinfo、日志和
  校验值。

每次构建生成 `BUILD-METADATA.json`，记录父仓库、两个 submodule、profile、
builder 架构、source mode 和并行数。
`onekvm` 还生成 `APK-METADATA.json`，记录 One-KVM、LuCI 和中文 i18n APK 的
包版本、字节数及 SHA256。正式产物由 `scripts/verify-output.sh` 检查 80 MiB
sysupgrade 上限、完整依赖闭包和禁止的 UDC/gadget 包。

## 更新上游

OpenWrt 与 One-KVM 必须分别更新和验证。不要同时移动两个 gitlink。

```bash
git -C upstream/openwrt fetch origin NEW_COMMIT
git -C upstream/openwrt checkout --detach NEW_COMMIT
```

随后同步修改 `locks/sources.lock`，完成两套配置构建和实机验证，再提交
gitlink 与锁文件。One-KVM 更新还必须重新生成源码归档 SHA256、`Cargo.lock`
并验证全部 patch。
