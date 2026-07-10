# 刷机说明

## 镜像用途

| 文件 | 用途 |
| --- | --- |
| `xg040g-minimal-factory.bin` | tcboot/Web U-Boot 首刷 |
| `xg040g-minimal-sysupgrade.bin` | 已有 OpenWrt 升级或恢复 |
| `xg040g-onekvm-factory.bin` | tcboot/Web U-Boot 直接刷完整版 |
| `xg040g-onekvm-sysupgrade.bin` | 已有 OpenWrt 升级到完整版 |
| `*-initramfs.itb` | 临时启动和诊断 |

刷写前先用 Release 的 `SHA256SUMS` 校验文件。

## 已运行 tcboot OpenWrt

推荐先通过 SSH 上传到 `/tmp`，执行镜像兼容性检查：

```bash
scp xg040g-onekvm-sysupgrade.bin root@192.168.1.1:/tmp/
ssh root@192.168.1.1
sysupgrade -T /tmp/xg040g-onekvm-sysupgrade.bin
sysupgrade /tmp/xg040g-onekvm-sysupgrade.bin
```

默认不使用 `-n`，以保留已有密码与网络配置。升级期间不要刷新页面；设备
通常需要约两到三分钟恢复网络。

## 原厂固件首次刷入

本仓库不提供 `tcboot.bin`。首次刷入依赖设备当前分区布局、tcboot 来源和
原厂固件 shell 状态，请先阅读以下资料：

- [OpenWrt XG-040G-MD 支持提交](https://github.com/openwrt/openwrt/commit/a6ecb09985fa7c14bae1c1bad7d42495737bc0ba)
- [godsun.pro 免拆机刷机记录](https://godsun.pro/blog/xg-040g-md.html)
- [N-WRT XG-040G-MD 刷机文档](https://nwrt.kuroneko.host/flashdocs/XG-040G-MD.html)

无 U 盘路线的基本顺序是：

1. 在原厂管理界面开启文档要求的服务，并使用设备标签上的账号登录。
2. 在同一局域网提供 HTTP/HFS 文件服务，将 tcboot 下载到设备 `/tmp`。
3. 校验文件和当前 MTD/UBI 布局，按对应教程写入 tcboot。
4. 重启进入 tcboot Web U-Boot，上传本项目 `factory.bin`。
5. 首次启动后验证 LuCI、SSH、MTD、UBI 和 USB host 状态。

不要把其他型号、UBI 路线或非 tcboot profile 的镜像混用。本项目 Actions
只发布 `nokia_xg-040g-md-tcboot` profile。

## 刷后检查

```bash
ubus call system board
df -h
lsusb
ls /sys/class/udc
/usr/bin/one-kvm --version
```

预期看到四个 xHCI root hub，且 `/sys/class/udc` 为空。

