# Tailor v1 iOS 开发任务拆解

| ID | 工作包 | 依赖 | 交付物 | 验收 |
| --- | --- | --- | --- | --- |
| IOS-01 | 项目骨架/导航/主题 | 无 | SwiftUI app、路由、暖白/深绿/陶土橙主题 | 12 页主路径可演示、可返回 |
| IOS-02 | 档案与编辑数据 | IOS-01 | SwiftData 模型和仓储 | 重启后保留草稿、章节和模板 |
| IOS-03 | PhotoKit/PhotosPicker | IOS-01 | 权限与选择服务 | 完整、受限、拒绝均不崩溃 |
| IOS-04 | 扫描协议与模拟服务 | IOS-02；真实模型待 P0 | 可替换 ScanService、恢复游标 | 中断后可继续、无匹配有引导 |
| IOS-05 | 确认/时间线/章节编辑 | IOS-02/04 | 交互页面 | 所有用户编辑即时持久化 |
| IOS-06 | PDF/分享 | IOS-05 | A4/Letter 本地渲染和 ShareLink | 飞行模式可生成；失败可重试 |
| IOS-07 | StoreKit 2 | App Store 商品待 P0 | 商品、购买、恢复 | Sandbox 成功/取消/恢复正确 |
| IOS-08 | 隐私/删除/遥测 | IOS-02 | 本地删除、匿名事件接口、诊断日志 | 不保留原图；可定位失败类别 |
| QA-01 | 自动化和手工回归 | IOS-03–08 | 测试报告 | 覆盖权限、后台、弱网、购买、导出 |
| DESIGN-01 | 设计/资产冻结 | Figma/Relay 待补 | 12 页状态稿与资源清单 | UI 验收可执行 |

## 子任务派发顺序

1. `IOS-01` 先交付页面骨架与模拟数据；本次原型已启动。
2. `IOS-02`、`IOS-03` 可并行；`IOS-04` 在 ML P0 关闭前只实现模拟协议。
3. `IOS-05` 依赖确认数据模型，`IOS-06` 与 `IOS-07` 可并行。
4. `QA-01` 必须在真实 StoreKit/ML 接入后执行；本次原型仅验证编译与流程。

## 必须随实现提交的横切项

- 埋点：`archive_created`、`scan_finished`、`confirmation_finished`、`preview_viewed`、`purchase_result`、`export_result`，不得含姓名、照片元数据或章节文字。
- 诊断日志：权限结果、扫描 task id/阶段、候选数量分桶、PDF 错误类别、StoreKit 交易状态；需掩码处理。
- 降级：PhotoKit 拒绝走手动选择；扫描失败保留游标；无候选允许补参考照；购买/PDF 失败不清空编辑。
- 发布/回滚：采用 App Store 分批发布；数据 schema 必须前向兼容，回滚不得删除本地档案。
