# 网络与恢复

## 正常拓扑

| 端口 | 作用 | 地址与服务 |
| --- | --- | --- |
| LAN2、LAN3、2.5G | `br-lan` 透明交换与管理 | 上游 DHCP；无 DHCP 时 IPv4LL |
| LAN4 | 独立 `br-pxe` | `10.40.0.1/24`、DHCP、TFTP、HTTP `:8081` |

正常系统没有 WAN 接口或 LAN 到 WAN 路由。LAN4 不加入管理交换桥，PXE DHCP
不会泄漏到上游。默认也没有 PXE 到上游的 forwarding；LuCI One-KVM 页面或
以下命令可按需切换：

```sh
xg040g-pxe-uplink status
xg040g-pxe-uplink enable
xg040g-pxe-uplink disable
```

开启后只建立 `pxe -> lan` 转发和出口 masquerade。PXE zone 的 LuCI、SSH、
One-KVM 等管理端口仍保持关闭。

BIOS 客户端先取得 `undionly.kpxe`，UEFI x86-64 客户端先取得 `ipxe.efi`；
iPXE 再次 DHCP 时会直接链入 `http://10.40.0.1:8081/boot.ipxe`，避免重复下载
iPXE 程序形成循环。

## 稳定名称与 IPv4LL

首次迁移会从有效设备 MAC 选择稳定管理 MAC；若设备只暴露占位或本地随机
地址，则生成并持久化一个本地管理 MAC。hostname 为
`xg040g-<MAC 后六位>`，Avahi 发布同名 `.local`、HTTP 和 SSH 服务。

DHCP 客户端始终运行。启动或租约丢失后等待 15 秒，仍无普通 IPv4 才启动
RFC 3927 IPv4LL；DHCP 地址出现后自动撤销 IPv4LL。`.local` 和 IPv4LL 只在
同一二层网络内有效。

## 保留配置升级

网络 schema 首次运行会无条件备份并替换旧的网络、DHCP 和防火墙配置。备份
保存在 `/etc/xg040g-network-backup/`，只保留最近一次迁移。root 密码、
One-KVM 数据和 UCI、rclone 配置以及 KVMSTORE 内容不受影响。

要再次恢复项目默认拓扑，可执行：

```sh
xg040g-network-mode apply-default --force
```

## 四级恢复

1. 正常情况下从 LAN2、LAN3 或 2.5G 口使用 DHCP 地址或
   `xg040g-xxxxxx.local`。
2. 上游无 DHCP 时等待约 15 秒，管理主机启用 IPv4LL 后仍访问同一 `.local`。
3. OpenWrt failsafe：开机后 12 秒的 preinit 窗口内触发 failsafe，仅把主机
   接到 LAN2，并使用 `192.168.1.2/24` 访问设备 `192.168.1.1`。
4. tcboot Web U-Boot：按设备既有 tcboot 流程进入恢复页面，LAN2 主机使用
   `192.168.1.2/24`，访问 `192.168.1.1` 并上传匹配版本的 `factory.bin`。

LAN4 的 `10.40.0.1` 只服务 PXE，不是管理或恢复入口。不要在管理交换端口间
制造物理环路；默认关闭 STP 是为了避免 DHCP 和 PXE 启动等待。
