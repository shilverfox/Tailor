# Tailor v1.1 · 四角色 PRD 一致性与发布门禁状态

**日期：** 2026-07-15  
**结论：** `Overall: BLOCKED`。本文件是当前唯一的放行依据；局部构建、页面截图或单个 UI 用例通过均不能替代全量门禁。

## 审计输入与角色结论

| 角色 | 审计产物 | 结论 |
| --- | --- | --- |
| 产品 | `07_prd_consistency_audit_2026-07-15.md` | PRD 与产品/设计规则存在两处待冻结冲突；发布不可放行 |
| 设计 | `design/audits/2026-07-15_prd_design_traceability_audit.md` | 规则文本部分覆盖，但 12 页正式高保真可点击设计不可签收 |
| iOS 研发 | 本文件“代码与运行态”审查 | 确认页可发现性已修复；关键 PDF、识别、时期编辑仍未满足 PRD |
| QA | `07_prd_test_evidence_audit.md` | 测试用例覆盖有所增加，但缺少 P0 真机/StoreKit/性能证据；不可放行 |

## 门禁矩阵

| 门禁 | 状态 | 可核验依据 | 未关闭条件 / Owner |
| --- | --- | --- | --- |
| G1 PRD 基线可读且范围明确 | PASS | `Tailor_v1_PRD.md` | 后续变更必须同时更新本表 |
| G2 PRD → 产品验收一致 | BLOCKED | 产品审计 AUD-01、AUD-02 | 产品冻结“年份或日期范围隐藏”范围；冻结素材不足时样章页数规则 |
| G3 正式视觉设计与原型 | BLOCKED | 设计审计 P0-01～P0-07 | Design 提供 12 页 + 权限、扫描、购买、导出失败态的可编辑源、状态标注和可点击路径 |
| G4 确认页人工选择可发现 | PASS（局部） | `ReviewFeatureView`、`testReviewMakesPendingChoicesDiscoverableBeforeTimeline`、真机安装 | 不等同于 06 页全部状态签收；仍需敏感/批量/零匹配/恢复真机证据 |
| G5 同一宠物端侧识别 | BLOCKED | `PhotoKitVisionScanner.swift` 仅候选检测/相似度实现 | ML 评审：参考照特征、阈值、准确率、幼年老年策略、耗时/耗电基准 |
| G6 敏感/永不使用/时期隐藏 | BLOCKED | 数据字段与 `isEligibleForArchive` 已存在 | 本地敏感分类策略及误判降级未冻结；日期范围隐藏、章节删除/合并/排序等 PRD 操作未完成或无验收证据 |
| G7 样章与正式 PDF 同源 | BLOCKED | `AlbumFeatureViews.swift` 有 8 页 SwiftUI 样章；`LocalPDFExporter` 为独立简化绘制 | 必须使用同一分页快照；完成 6–8 页水印样章、无水印 PDF 的内容一致性与大相册性能预算 |
| G8 购买与隐私发布准备 | BLOCKED | StoreKit 2 代码存在 | App Store Connect 商品、地区定价、隐私标签、Sandbox 成功/取消/失败/恢复证据缺失 |
| G9 无通知/无自动回忆 | BLOCKED | 静态扫描未找到通知 API | 冷启动、前后台、照片库变化、周年等真机运行记录与系统通知中心/日志证据缺失 |
| G10 全量测试与真机证据 | BLOCKED | 单元测试、局部 UI 自动化、真机构建安装已完成 | 当前缺少可追溯的全量测试 result bundle；P0 用例未形成逐项真机截图/日志/结果证据 |
| G11 删除、离线、失败保留 | BLOCKED | 局部单元测试覆盖失败保留 | 真机删除语义、飞行模式、权限撤销、PDF 分享失败和恢复路径未完成全量回归 |

## 代码与运行态：已验证的有限事实

- 真机 Debug 包可构建、安装并启动（bundle id `com.tailor.prototype`）。
- 照片确认已增加 `High / Needs review / Sensitive / Excluded` 可见分组；待确认缩略图可点开并明确选择“这是/不是”。
- 当仍有待确认照片时，创建时间线先显示决策提示；不再静默跳过。
- `ArchivePhoto` 已保存敏感状态、排除原因和本地日期范围，`selected + normal` 是下游素材池的基础过滤条件。
- 静态检索未发现 `UNUserNotificationCenter`、通知授权或远程通知注册调用。

以上均为局部事实，**不构成 v1 发布通过结论**。

## 放行顺序

1. **产品**先冻结 G2 的两处冲突，并更新 PRD/需求/测试为同一口径。
2. **设计**完成 G3 的正式设计源与全状态可点击原型，设计审计复核为 PASS。
3. **研发**关闭 G5/G6/G7 的实现差距，特别是同源 PDF、日期范围隐藏和时间线编辑能力。
4. **测试**以冻结后的口径执行 P0 真机、StoreKit、离线、无通知和大相册测试，保存可追溯结果。
5. 四角色复核本表全部为 PASS 后，才可标记 `Overall: PASS` 并进入发布验证。

## 禁止的放行表述

在本表为 `BLOCKED` 期间，不得使用“全部功能完成”“12 页高保真原型完成”“已通过全量测试”“可发布”或等价结论。可以表述为“确认页可发现性修复已部署并完成局部回归”。
