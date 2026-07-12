# 2026-07-13 持久化 PXE 端口与最终固件验证

## 构建与刷机

- OpenWrt commit：`4984eff3c34a5b8d7995e2b2a0a3823bba31c1fc`
- One-KVM commit：`7753c83e27d20ba31d19daafdddedada7e89e32c`
- minimal 干净构建、One-KVM 最终增量构建及 One-KVM 离线热缓存构建均成功。
- 最终 sysupgrade 大小：`59,156,775` 字节。
- 最终刷机镜像 SHA256：
  `0ddf8c05c9c12b12b561d8848eae787a4647425c6112db14eea8bbe6b554df4e`
- `sysupgrade -T` 与远端 SHA256 均通过；保留配置升级后约 50 秒恢复 SSH。
- `xg040g-switch-management 2.0.0-r2`、`luci-app-one-kvm 20260710-r9`
  和 `one-kvm 0.2.3-r4` 已实机确认。

实机测试发现并修复了两个仅在异步切换时出现的问题：基础 BusyBox 不提供
`nohup`，以及 PXE 上联脚本在 `--no-reload` 时误返回 1。最终版本改用
`start-stop-daemon` 脱离 LuCI/RPC 会话，并保证正常关闭状态返回 0。

## 默认交换机与管理

- schema v2 默认 `pxe.port=none`。
- `lan2 lan3 lan4 eth1` 全部且仅属于 `br-lan`。
- 未创建 `br-pxe` 或 `pxe`，也没有 `10.40.0.1`、PXE DHCP/TFTP、8081 或
  8083 监听。
- 管理 DHCP 客户端、15 秒 IPv4LL 后备和稳定
  `xg040g-f5040c.local` 均已观察到；DHCP 成功后 IPv4LL 自动撤销。
- Avahi 固定 `allow-interfaces=br-lan`，PXE 启用时日志中没有把 `br-pxe`
  注册为 mDNS 接口。

## PXE 端口矩阵

- LAN4：唯一进入 `br-pxe`，其余三口保留在 `br-lan`。
- LAN3：唯一进入 `br-pxe`，其余三口保留在 `br-lan`。
- 2.5G (`eth1`)：唯一进入 `br-pxe`，其余三口保留在 `br-lan`。
- `none`：删除 PXE 接口、DHCP、防火墙和监听，四口完整返回 `br-lan`。
- 每个启用状态都创建 `10.40.0.1/24`，dnsmasq 提供 DHCP/TFTP，独立
  uhttpd 监听 `10.40.0.1:8081`。
- PXE 上联开关正确创建和清理 `pxe -> lan` forwarding 与 LAN masquerade；
  未选择端口时 RPC 拒绝启用上联。
- LAN4 选定后重启，端口选择、桥成员、DHCP/TFTP/HTTP 均自动恢复；测试结束
  后已手动恢复 `none`，没有自动回退机制。
- LAN2 因承担本轮远程管理链路未做运行态断线测试，已由五状态自动化测试验证
  配置生成和唯一桥成员约束。

LuCI 的错误确认值和非法端口均被 RPC 拒绝；桌面和 390 px 移动视口无横向
溢出。确认对话框明确说明所选端口失去 LuCI、SSH、mDNS 且不会自动回退，
取消操作不会修改设备。

## 回归结果

- 两个 xHCI 控制器、四个 USB root hub 正常，`/sys/class/udc` 为空。
- One-KVM 无采集卡运行 RSS 约 `63.9 MiB`，`MemAvailable` 约 `144-149 MiB`。
- overlay 可用约 `164.1 MiB`。
- `one-kvm-codec-check` 的 H.264、H.265、VP8、VP9 720p 单帧测试全部通过。
- LuCI、SSH、One-KVM、Statistics、collectd thermal 与 `cpu-thermal` 正常；
  实测温度约 `55.2 C`。
- 本轮设备未接入 MS2109、CH340/CH9329 或 USB3 外置盘；这些硬件沿用既有
  实测结论，本轮只确认驱动和 host-only USB 回归。
- 没有第二根网线，因此动态端口上的实体 DHCP 客户端与 iPXE 启动复测仍保留为
  发布前待测项；旧固定 LAN4 固件的 Hyper-V FirPE/SystemRescue 闭环不受影响。
