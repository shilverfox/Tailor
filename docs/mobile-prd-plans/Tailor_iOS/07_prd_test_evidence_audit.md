# Tailor v1 PRD → 测试 → 证据门禁审计

审计时间：2026-07-15  
审计范围：新版 [`Tailor_v1_PRD.md`](Tailor_v1_PRD.md) 第 2、3、5、6、7 节；[`04_test_cases.md`](04_test_cases.md)；当前 `TailorTests`、`TailorUITests`、本地 Xcode 结果、真机既有扫描证据。

## 结论

**发布门禁：不通过。** 本轮实现补齐了重要的数据安全边界和 8 页预览 UI，但 PRD 的 P0 中仍有可复现的功能/证据缺口。不能以“构建成功”或定向单测成功替代完整验收。

| 严重度 | 数量 | 结论 |
| --- | ---: | --- |
| P0 阻断 | 5 | 不可进入发布/全量验收通过状态 |
| P1 缺口 | 5 | 可继续开发，但应在下一轮回归前补齐 |
| P2 缺口 | 3 | 文档、稳定性与可观测性改进 |

## 已验证的正向证据

| 项目 | 当前证据 | 结论 |
| --- | --- | --- |
| 敏感/永不使用数据语义 | `ArchivePhoto` 已有 `sensitivityState`、`excludedReason`、`localDateRange` 和 `isEligibleForArchive`；旧 JSON 默认 `.normal` | 代码级通过 |
| 敏感素材下游过滤 | `MilestoneRootView.updatePhotos` 会清除所有章节 `photoIDs`；预览和 PDF 均再次以 `isEligibleForArchive` 过滤 | 代码级通过，仍需端到端回归 |
| 隐藏章节下游过滤 | 预览 `visibleChapters` 与 PDF 循环均过滤 `isHidden` | 代码级通过，仍需端到端回归 |
| 免费样章页数 | `AlbumPagesPreview` 固定封面、致意、目录、两组章节 opener/选片、结尾，共 8 页；所有页经 `AlbumPage(watermarked: !purchased)` 渲染 | 代码级通过，缺 UI 证据 |
| 无通知静态审计 | 对 `Tailor/**/*.swift` 搜索 `UserNotifications`、`UNUserNotification`、通知授权/远程注册 API 无匹配；仅有 PhotoKit 授权 | 静态通过 |
| 数据安全单测 | `TailorFeatureTests` 覆盖敏感状态、旧数据迁移、永不使用 round-trip、隐藏章节 round-trip、失败保留、扫描 checkpoint | 定向单测通过（此前 `xcodebuild test -only-testing:TailorTests` 退出码 0） |

## P0 发布前必须关闭项审计

| PRD P0 | 实现/测试证据 | 状态 | 阻断说明 |
| --- | --- | --- | --- |
| 1. 同一宠物端侧识别模型、阈值、耗时/耗电预算 | `PhotoKitVisionScanner` 使用动物检测和 feature print，但无冻结模型版本、评测集、阈值依据、耗时/耗电测试报告 | **P0 阻断** | 不能证明幼年到老年、同画面多宠物、相似宠物的正确性与资源预算 |
| 2. App Store Connect 商品、地区定价、审核、隐私标签 | 代码有 `tailor.life_archive.unlock`；只有 mock/服务级测试，无 StoreKit 配置、Sandbox 成功/取消/恢复证据 | **P0 阻断** | 正式购买交付尚未验收 |
| 3. 12 页及失败态正式视觉规格 | 有 `design/` 文档和 HTML 原型，但没有可追溯的 Figma/Relay 正式规格或逐页失败态对照证据 | **P0 阻断** | 无法完成产品要求的设计基线验收 |
| 4. 敏感策略、误判降级、永不使用迁移/删除 | 数据结构、手动决定、迁移默认值及下游过滤已实现；扫描器明确不做病情/死亡推断 | **条件通过** | 需补真机“敏感→永不使用→章节/封面/预览/PDF 均移除”证据及删除档案后的本地数据检查 |
| 5. 6–8 页真实水印预览与无水印完整 PDF 的内容一致性、容量和性能 | UI 预览固定 8 页；`LocalPDFExporter` 仍只输出封面和可见章节的流式 PDF，不包含致意、目录、选片页、结尾，也没有预览水印/正式 PDF 同源分页器 | **P0 阻断** | 预览与正式 PDF 的结构不一致，直接不满足 PRD 5.3.2 与 P0-5 |
| 6. 无通知/无自动回忆回归 | 静态搜索无通知 API；但未见覆盖冷启动、前后台、照片库变化、周年日期的有效真机/UI 结果 | **P0 阻断（证据不足）** | 静态结果不能证明运行期不自动扫描/展示照片 |

## 功能与测试门禁

| 领域 | 现状 | 判定 |
| --- | --- | --- |
| `04_test_cases.md` | 已覆盖权限、敏感、永不使用、隐藏时期、8 页样章、购买失败、后台锁屏、离线、无通知回归 | 通过（测试设计） |
| `TailorTests` | 数据模型、失败保留、checkpoint、SwiftData、基础 PDF header 覆盖 | P1：没有验证 PDF 页数/页面内容/水印/样式/页尺寸，也没有验证“敏感变化后章节持久化清理” |
| `TailorUITests` | 12 页面可渲染的 demo route 骨架存在 | **P0：当前 UI 测试未全绿** |
| 全量 `xcodebuild test` | 本轮写入 `/tmp/Tailor-PRD-Audit.xcresult` 未形成有效 `Info.plist`，不能作为通过证据 | **P0：执行证据无效** |
| 既有 UI 结果 | `Test-Tailor-2026.07.15_12-42-45-+0800.xcresult` 明确记录 `testReviewMakesPendingChoicesDiscoverableBeforeTimeline()` 失败 | **P0：回归失败** |
| 真机 | 已有历史证据：真实 PhotoKit 扫描进度从 0 恢复；无新版敏感/预览/PDF/无通知全链路截图、日志或录屏 | P1：证据不足 |

## P0 阻断明细与关闭标准

1. **PDF 与 8 页预览不同源。** 将预览和正式 PDF 改为共享同一页模型/渲染计划；未购买为同页模型加水印，购买后使用同一用户确认内容去水印并扩展完整章节。添加 PDF 页数、页标题、页尺寸、隐藏/敏感/永不使用过滤的自动化测试，并提供 A4/Letter 真机导出物。
2. **UI 回归已失败。** 更新 `TailorOnboardingUITests.testReviewMakesPendingChoicesDiscoverableBeforeTimeline` 到新确认页的 menu/context-menu 交互和无未确认素材的时间线守卫；全量 `xcodebuild test` 生成可读取 xcresult 且 0 failed。
3. **端侧识别未验收。** 冻结模型/阈值，提供猫/狗、幼年/老年、多宠、低清、无日期样本集及准确率、耗时、耗电门槛和真机报告。
4. **StoreKit 未验收。** 提供 StoreKit 配置或 Sandbox 测试记录：成功、取消、失败、恢复、重装后权益；确认商品、地区价格、隐私标签。
5. **无自动回忆缺运行期证据。** 在真机执行 TC-21 至 TC-25：冷启动、前后台、照片库变更、周年日期、长时间未使用；附通知中心、屏幕录制和日志证据。

## P1 缺口

| 编号 | 缺口 | 建议 |
| --- | --- | --- |
| P1-01 | `TailorUITests` 当前断言仍引用旧确认页的 `NEEDS REVIEW` 按钮/决定 sheet | 跟随新版 menu/context action 更新，并为敏感、永不使用、隐藏章节、8 页预览增加测试标识与路径 |
| P1-02 | PDF 单测只断言 `%PDF` 文件头 | 增加页数、A4/Letter MediaBox、文本/水印、过滤资产和删除文件测试 |
| P1-03 | `pageSize` 为页面状态，未见持久化到 `PetProfile`/`ArchiveDocument` | 将页尺寸作为档案编辑状态保存，重启后回归 |
| P1-04 | 章节仅有 `photoIDs.first` 作为隐式封面，模型没有明确 `coverPhotoID` | 增加迁移和“封面被标记 neverUse 后回退”的测试 |
| P1-05 | 飞行模式、iCloud 未下载原图和 1,000+/10,000+ 相册仍无执行报告 | 依照 TC-16/19 在真机验证内存、耗时、暂停恢复与失败文案 |

## P2 缺口

| 编号 | 缺口 | 建议 |
| --- | --- | --- |
| P2-01 | `git diff --check` 报多份规划文档末尾空白行 | 在最终提交前清理格式噪声 |
| P2-02 | 质量证据未集中存档 | 将有效 xcresult、真机截图/录屏索引写入 `docs/qa/evidence/` |
| P2-03 | 未见本地匿名漏斗事件的验收 | 明确 v1 是否实现；若实现，测试数据不含照片、名字、元数据、章节文字 |

## 当前门禁状态

**结论：阻断。** 可继续进行设计/开发迭代，但不得宣称新版 PRD 已完成或进入发布候选。P0 明细全部关闭、全量测试产出有效且绿色、真机 P0 回归证据归档后，才能重新审计。
