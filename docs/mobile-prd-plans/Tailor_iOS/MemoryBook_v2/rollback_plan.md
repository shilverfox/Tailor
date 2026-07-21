# Tailor MemoryBook v2 回滚方案

## 触发条件

- 扫描导致持续高温、不可恢复卡死或数据丢失。
- v2 草稿迁移损坏 v1 档案。
- Final Preview 与 PDF 严重不一致。
- StoreKit 错误授权、重复收费或已购无法恢复。
- P0 崩溃、照片越权或隐私泄漏。

## 回滚动作

1. 停止向 TestFlight/App Store 推进当前 build。
2. 保留用户本地原档案；禁止破坏性 schema 回写。
3. 关闭新建 v2 Smart Draft 入口，旧档案继续只读/导出；不得删除用户编辑。
4. StoreKit 异常时禁用新购买，保留 Restore 和本地已购权益读取。
5. 发布修复 build；无法及时修复时从 App Store Connect 移除可用版本或停止分阶段发布。

## 数据原则

- v1→v2 使用副本迁移，原始档案不覆盖。
- 失败事务不替换最近成功 revision。
- 临时 PDF 失败即删除，已成功 PDF 和系统照片不受回滚影响。
- 回滚前后记录 build、schemaVersion、document revision 和 StoreKit transaction 状态，不记录照片内容。
