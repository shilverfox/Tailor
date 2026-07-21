# Tailor v2 QA 可执行基线与验收清单

> 负责人：QA  
> 日期：2026-07-20  
> 状态：研发实施期基线；最终独立验收尚未开始  
> 唯一需求基线：Tailor_v2_PRD.md  
> 原型基线：design/prototype_v2/*  
> 用例来源：MemoryBook_v2/04_test_cases.md

## 1. 判定规则

- **通过**：当前提交上有可复现自动化结果、真机证据或可核验渲染产物，且证据覆盖该要求本身。
- **失败**：当前代码编译失败、自动化断言失败、运行结果与 PRD 冲突或产生数据损坏。
- **缺证据**：代码看似存在，但没有覆盖相应验收范围的测试、fixture、截图/PDF、StoreKit 结果或真机记录。
- 旧 v1 测试通过不能证明新 v2 页面、路由或门禁通过。
- UI 截图不能替代持久化、恢复、PDF 几何或内容安全测试。

## 2. 当前自动化基线

### 2.1 已执行结果

| 批次 | 命令/范围 | 结果 | 证据 |
| --- | --- | --- | --- |
| B-01 | xcodebuild 只运行 TailorTests，研发 v2 并发改动前 | **通过** | 107 tests，0 failures，48.654s；xcresult：/tmp/TailorV2QADerivedData/Logs/Test/Test-Tailor-2026.07.20_20-40-15-+0800.xcresult |
| B-02 | 加入 v2 模板保护契约后两次复跑并发修改中的工作树 | **失败** | 第一次报 PreviewFeatureView 缺少 changeStyle，第二次报 extra argument changeStyle；调用方与被调用方接口未在稳定快照同步，测试均未进入执行阶段 |
| B-03 | UI Tests 全量 | **缺证据** | 尚未在研发合并后的稳定构建上执行 |
| B-04 | 真机、StoreKit、A4/Letter PDF 人工验收 | **缺证据** | 等待研发候选版本 |
| B-05 | 冻结树全量 TailorTests | **失败** | 110 tests，109 passed，1 failed；`testFocalCropPolicyConvertsVisionCoordinatesAndCentersWithinSafeRange` 稳定失败；xcresult：`/tmp/TailorV2FinalQADerivedData/Logs/Test/Test-Tailor-2026.07.20_21-17-30-+0800.xcresult` |
| B-06 | B-05 失败用例定向复跑 | **失败** | 1 test，1 failure；生产 `MemoryBookBuilder` 的三图页面未带入主体焦点裁切，`cropOffset.width` 实际为 0；xcresult：`/tmp/TailorV2FinalQADerivedData/Logs/Test/Test-Tailor-2026.07.20_21-20-18-+0800.xcresult` |
| B-07 | 冻结树 TailorUITests 全量尝试 | **环境中断/不可作为全量结论** | 结果包记录 9 项：5 passed、4 failed；其中 1 项为测试断言、1 项 App 未运行、1 项 signal kill、1 项人工取消；Xcode 同时报 LLDB version store 和重复 Accessibility bundle 警告，并自动重启 runner。xcresult：`/tmp/TailorV2FinalUIQADerivedData/Logs/Test/Test-Tailor-2026.07.20_21-21-13-+0800.xcresult` |
| B-08 | B-07 中档案删除断言定向复跑 | **通过** | 1 test，0 failures；证明 B-07 的档案断言不是稳定产品失败。xcresult：`/tmp/TailorV2FinalUIQADerivedData/Logs/Test/Test-Tailor-2026.07.20_21-26-42-+0800.xcresult` |
| B-09 | B-07 中 Book Check 对齐与 Crop 事务定向复跑 | **通过** | 2 tests，0 failures；证明对应两项中断由长跑 runner 状态造成。xcresult：`/tmp/TailorV2FinalUIQADerivedData/Logs/Test/Test-Tailor-2026.07.20_21-27-27-+0800.xcresult` |

### 2.2 本轮新增自动化门禁

位于 TailorTests/TailorFeatureTests.swift：

1. testV2VisualOnlyTemplateApplicationChangesTokensWithoutChangingAuthoredPages
2. testV2RearrangeUnlockedProtectsLockedPageAndReportsItsImpact
3. testV2FiveTemplatesExposeFiveDistinctEditorialSignatures

这些用例已在 B-05 中执行并全部 **通过**。它们证明 visual-only、rearrange-unlocked 与五模板签名的纯模型契约成立，但不能替代运行态、真机和 PDF 像素验收。

## 3. 当前覆盖审计

| PRD 模块 | 当前证据 | 状态 | 仍需补齐 |
| --- | --- | --- | --- |
| 01–06 权限/参考照/扫描/确认 | 扫描恢复、决策持久化、neverUse、批量确认及 UI fixture 已有测试 | 部分通过 | 真机完整/受限/拒绝权限；热降速；大相册；权限变化 |
| 07 Smart Draft | MemoryBookBuilder.analyze/build 有模型基础 | 缺证据 | 独立页面、真实进度、取消、稍后继续、失败重试、简单时间线降级、不得重扫全相册 |
| 08 Story Plan | 章节顺序、标题、隐藏、持久化有部分测试 | 缺证据 | 合并、拆分、代表图、回选片、照片集合变化只标记 needsReflow、锁定页保护 |
| 09 Book Style | 五枚举、Style token、双纸张 RenderPlan 已测试 | 部分通过 | 首次选择流程、五模板结构差异盲测、6 类代表页基准、默认 Warm Paper |
| 10 Book Preview | reader、页码、横屏、免费样章已有 UI 测试 | 部分通过 | v2 固定 6–8 页样章组合、未开放页不可读、真实照片水印、四个 v2 路由 |
| 11 Page Editor | 图片/文字/层级/锁定/Undo/Redo/组合/外观已有大量模型和 UI 测试 | 部分通过 | v2 入口回归、只有当前元素响应手势、首次编辑自动锁页、后台保存失败恢复 |
| 12 Pages | 复制、重排、布局迁移、图层有测试 | 部分通过 | 新增注记页、保护结构页、合法插入位置、锁定/修改/迁移缩略标记 |
| 13 Photo Edit | Fit/Fill、裁切、替换、旋转、Cancel/Done/Undo 有测试 | 部分通过 | 真机双指手势、页面最大范围、非选中图片不响应、无难点缩放柄的视觉验收 |
| 14 Text Edit | 连续字号、字体、颜色、对齐、旋转、溢出和共享渲染有测试 | 部分通过 | 打开面板不自动弹键盘、8 字体逐项 UI、旋转柄真机操作、添加文字入口 |
| 15 Page Layout | 兼容布局、溢出移新页、Cancel、Undo、锁定图片保护已有测试 | 部分通过 | 3–5 候选、Recommended 原因、裁切保留率、确认文案和原子 Undo UI |
| 16 Apply Style / Regenerate | Style override、锁定元素保护及新增 v2 契约测试 | 缺证据 | 新增用例尚未通过；整书恢复快照、needsReflow 默认范围、二次确认、单次 Undo UI |
| 17 Book Check | 缺失 asset、文字溢出、低 PPI、重复、裁切、对比度及修复有测试 | 部分通过 | 完整文档购买无关、忽略建议持久化、问题页往返保持位置、安全修复影响预览 |
| 18 Purchase | failed/pending/cancelled/restored 的模型与 UI fixture 已有 | 部分通过 | StoreKit 真实商品、离线、地区价格、付费只拦最终预览/导出、不拦完整编辑 |
| 19 Final Preview/PDF | 共用 RenderPlan、A4/Letter、300 DPI、失败无半成品、revision snapshot 有测试 | 部分通过 | v2 完整无水印逐页预览、真实 PDF 像素 diff ≤1 pt、取消进度、Share Sheet 真机 |
| 20 Archive | export record、路径恢复、删除不影响权益有测试 | 部分通过 | 最近 PDF 丢失重导、Refresh 只增量、不覆盖 v2 文档、完整删除范围 |
| v1→v2 迁移 | 零散旧字段解码测试 | 缺证据 | 副本迁移、失败保留旧档案/旧 PDF、一个版本周期保留、确认后标记完成 |
| 自动质量 KPI | 无 20 本黄金样例及人工评分记录 | 缺证据 | ≥70% 无需结构重做；近重复；跨年份；配方节奏；主体安全 |
| 模板差异 KPI | 无盲测结果 | 缺证据 | 灰度盲测 ≥80%；任意两模板至少 3 个结构差异 |

## 4. 黄金 fixture 门禁

当前仓库只有局部文字/裁切 fixture，尚未发现 04_test_cases.md 规定的四套完整 v2 文档及其 5 模板 × A4/Letter 基准，因此整体状态是 **缺证据**。

| Fixture | 数据要求 | 必须生成的证据 |
| --- | --- | --- |
| GF-01 | 12 张横竖混合、3 章、1 组近重复 | JSON 文档；5×2 全页 PNG；5×2 PDF；预览/PDF geometry manifest |
| GF-02 | 112 张、4 章、多人/多宠、低清、极端比例 | 同上；另附生成耗时、取消响应、内存峰值 |
| GF-03 | 仅 3 张最小成册 | 同上；证明不复制图片、不虚构章节 |
| GF-04 | 缺失 asset、敏感、排除、隐藏时期、长文本 | Book Check issue 快照；四层零泄漏证明；失败/替换/恢复记录 |

基准文件固定放在 artifacts/v2-qa/golden/<fixture>/<template>/<paper>/，不得写入用户系统相册。

## 5. 可执行验收矩阵

### 5.1 功能主流程

| ID | 场景 | 操作 | 通过条件 | 证据 |
| --- | --- | --- | --- | --- |
| F-001 | 新用户完整链路 | 01→20，使用 GF-01 | 每一页面和返回路径与原型合同一致；草稿不丢 | UI test + 逐页截图 + 最终 PDF |
| F-002 | 最小成册 | 3 张确认照片创建书 | 可生成；不复制照片；章节/页数按素材收缩 | 单测 + 文档 manifest |
| F-003 | Smart Draft 取消/继续 | 生成中取消并重进 | 确认结果保留；不重扫相册；可继续或重试 | UI test + repository snapshot |
| F-004 | Smart Draft 降级 | 注入规划失败 | 可重试/简单时间线/返回照片；无数据丢失 | 单测 + UI test |
| F-005 | Story Plan 结构编辑 | 改标题、代表图、排序、合并、拆分、隐藏 | 语义更新；受影响未锁页仅 needsReflow；锁定页不变 | 模型测试 + UI test |
| F-006 | 免费样章 | 未购买打开 Preview | 仅 6–8 页固定类型、均有水印；整册结构可见但未开放内容不可读 | UI test + 截图 |
| F-007 | 完整编辑不收费 | 未购买进入 Editor 并保存 | 图片/文字/页面全部可编辑，不出现 Purchase | UI test |
| F-008 | Book Check 跳转修复 | 从 issue 进入指定元素后返回 | 定位精确；修复后回到原 issue 位置 | UI test |
| F-009 | 购买失败返回 | 在最终预览门禁取消/失败 | 回到同一预览/检查状态；文档 fingerprint 不变 | 模型 + UI test |
| F-010 | 档案继续 | 结束进程后从 Archive 继续 | 打开最后保存 revision 和最近页码；不自动扫描/重排 | UI test + repository snapshot |

### 5.2 共享模型与内容安全

| ID | 验收项 | 通过条件 |
| --- | --- | --- |
| M-001 | 单一文档源 | Editor、Reader、PDF 消费相同 MemoryBookDocument/Page/Element revision |
| M-002 | 归一化几何 | frame/rotation/zIndex/crop 跨设备预览与两纸张可确定解析 |
| M-003 | Visual-only | frame/crop/rotation/zIndex/分页/页锁零变化 |
| M-004 | Rearrange unlocked | 只改未锁页面；锁定页逐字段相等；照片不丢不重 |
| M-005 | 内容过滤 | sensitive/excluded/neverUse/hiddenPeriod 在生成、候选、预览、PDF 四层零出现 |
| M-006 | 中性叙事 | 无用户确认时不得出现 first/favorite/last、疾病、死亡原因或宠物口吻文案 |
| M-007 | 节奏 | 同一配方不得连续超过 2 页；章节遵循 opener→hero→sequence→quiet/transition |
| M-008 | 近重复 | 同组默认最多 1 张，用户显式保留时例外 |

### 5.3 恢复、失败与生命周期

| ID | 注入点 | 通过条件 |
| --- | --- | --- |
| R-001 | 扫描后台/锁屏/进程终止 | 恢复最后 checkpoint 和决策，不从 0 重扫 |
| R-002 | serious/critical 热状态 | 降并发/可恢复暂停；不得形成永久 Paused；文案可理解 |
| R-003 | 编辑器后台/杀进程 | 恢复最后成功事务；不自动 reflow |
| R-004 | 保存失败 | 内存编辑保留；可重试；不退出编辑器 |
| R-005 | PhotoKit asset 删除 | 占位；Book Check 阻断；替换后解除；不崩溃 |
| R-006 | 权限 full→limited/denied | 已编辑文档保留；不可用资产明确阻断；可管理权限 |
| R-007 | PDF 渲染失败/取消 | 临时半成品删除；草稿、纸张、revision 保留 |
| R-008 | StoreKit 无网 | 编辑/样章继续；购买/恢复可重试；不错误授权 |

### 5.4 PDF 与双渲染

| ID | 验收项 | 通过条件 |
| --- | --- | --- |
| P-001 | A4/Letter | 页尺寸、页数、顺序与对应 Final Preview 一致 |
| P-002 | 几何 | 核心 frame/crop/rotation/zIndex/text 几何误差 ≤1 pt |
| P-003 | 文字 | 8 字体 token、连续字号、颜色、对齐、旋转、换行、分页一致 |
| P-004 | 图片 | Fit 不裁切不拉伸；Fill/Crop 与预览一致；低 PPI 正确提示 |
| P-005 | revision 冻结 | 导出期间编辑不能污染当前导出；返回编辑后新导出使用新 fingerprint |
| P-006 | 持久文件 | 成功 PDF 位于 App Exports；重启后可从 Archive 打开 |
| P-007 | 零泄漏 | GF-04 禁用 asset 不出现在 PDF 对象、缩略图或渲染输出 |

### 5.5 付费门禁

| ID | 状态 | 通过条件 |
| --- | --- | --- |
| G-001 | 未购买 | 可扫描、确认、规划、生成、完整编辑、Book Check；只能看水印样章 |
| G-002 | 尝试完整最终预览/导出 | 唯一触发 Purchase 的位置 |
| G-003 | purchased/restored | 完整无水印 Final Preview 和重复导出开放 |
| G-004 | cancelled/failed/pending | 不授权；返回原状态；所有编辑保留 |
| G-005 | 删除档案 | 不撤销 Apple ID 购买权益 |
| G-006 | Debug bypass | 仅显式 Debug 参数有效；UI test/Release/生产绝不隐式绕过 |

### 5.6 编辑器回归

| ID | 验收项 | 通过条件 |
| --- | --- | --- |
| E-001 | 图片选中隔离 | 手势只修改当前选中元素；触摸未选中元素的首个手势只切换选择 |
| E-002 | 图片变换 | 等比缩放、自由旋转、移动、删除、替换、裁切、层级、锁定均可用 |
| E-003 | Fit/Fill | 默认 Fit 完整显示且框匹配内容比例；仅 Fill/Crop 裁切 |
| E-004 | 文字 | 添加/选中/输入/移动/删除/锁定/层级、连续字号、颜色、对齐、8 字体可用 |
| E-005 | 文字面板 | 打开不聚焦输入框；点击正文才弹键盘；旋转柄围绕中心连续旋转 |
| E-006 | 页面 | 增加、复制、合法删除、重排、结构页保护、锁定标记可用 |
| E-007 | Undo/Redo | 每个手势结束为一个事务；布局/模板应用整次一个事务 |
| E-008 | 自动锁定 | 首次几何、裁切、层级、文字内容修改后页面进入布局保护 |
| E-009 | 自动保存 | 返回 Preview 和切后台保存；失败可重试且不丢内存状态 |

## 6. 设计与测试联合验收

设计验收不能只看静态原型，必须使用同一黄金 fixture 对运行态和 PDF 共同签字：

1. 01–20 每页至少覆盖 success；状态矩阵中的 loading/empty/failure/recovery/permission/payment 按适用页面覆盖。
2. 五模板每套至少覆盖 Cover、Contents、Chapter Opener、Single Hero、Sequence/Grid、Quiet Note/Closing 六类页。
3. 同一页面提供原型、运行截图、PDF 渲染截图三联对比。
4. 记录字体、字号、颜色、间距、圆角、图片处理、层级、裁切和分页差异；P0/P1 必须修复后复验。
5. 模板灰度盲测至少 5 名评审、每人随机 20 题；总体识别率 ≥80%。
6. 自动生成质量由产品/设计/QA 对 20 本样例评分；≥70% 无需结构重做才通过。

## 7. 提测进入条件

以下全部满足后，QA 才开始最终独立验收：

- 当前分支 BUILD SUCCEEDED，单元测试与 UI test 均可执行。
- PRD 页面 01–20 均有可达运行入口，不用旧页面伪装 v2 页面。
- GF-01～GF-04 及五模板×双纸张基准完整。
- StoreKit 配置覆盖 purchased/restored/cancelled/pending/failed/offline。
- 研发提供迁移前后数据、恢复快照和导出 revision 的可观察证据。
- 设计提供追踪表中仍缺的失败态、重生成确认、文字编辑和档案状态稿。

## 8. 研发冻结前 QA 结论（历史记录）

- **通过**：研发 v2 并发改动前的 107 个单元测试基线。
- **失败**：当前工作树编译失败；PreviewFeatureView.changeStyle 在并发修改期间先后出现缺参和多参，尚无稳定可测试快照。
- **缺证据**：全量 v2 UI、四套黄金 fixture、20 本自动质量、模板盲测、真机恢复、StoreKit、最终 PDF 三联对比、v1→v2 副本迁移。
- 当前不能判定“功能完成”或“可以发布”。

## 9. 冻结树最终独立验收（2026-07-20）

### 9.1 稳定失败

| ID | 严重度 | 对应 PRD/账本 | 结果 |
| --- | --- | --- | --- |
| QA-V2-001 | P1，发布门禁失败 | PRD 7.1；M-002；P-002；P-004 | 三图 `photoSelection` 页面没有把 `ArchivePhoto.subjectRegion` 转为初始 `cropOffset`。同一用例全量和定向两次均得到 `cropOffset.width == 0`，会使自动排版不能主动保护偏离中心的宠物主体。单图封面焦点路径通过，因此缺陷范围是多图生产构建路径。 |

### 9.2 QA 账本逐组判定

| 账本组 | 通过 | 失败 | 缺证据/仅部分覆盖 |
| --- | --- | --- | --- |
| F-001～F-010 主流程 | F-002；F-008 的 Book Check 定位局部路径 | 无新增稳定 UI 功能失败 | F-001、F-003～F-007、F-009～F-010 缺完整 v2 UI/真机闭环；F-005 仅模型部分覆盖 |
| M-001～M-008 模型安全 | M-001、M-003、M-004、M-005、M-008 | M-002 的多图焦点裁切失败 | M-006 中性叙事与 M-007 页面节奏尚无黄金样例验收 |
| R-001～R-008 恢复 | R-001、R-007 有模型级局部证据 | 无稳定复现失败 | 真机后台/锁屏/杀进程、热状态、权限变化、保存失败和 StoreKit 离线均缺证据 |
| P-001～P-007 PDF | P-003、P-005；P-001/P-006/P-007 有模型级局部证据 | P-002、P-004 被 QA-V2-001 阻断 | 没有 GF-01～GF-04 的五模板×双纸张正式基准，也没有 Preview/PDF ≤1 pt 三联人工签字 |
| G-001～G-006 付费 | G-004、G-005 模型契约通过 | 无稳定复现失败 | 真实 StoreKit 商品、地区价格、离线、恢复、唯一门禁位置及 Release 无 bypass 缺证据 |
| E-001～E-009 编辑器 | 多数图片、文字、裁切、布局、锁定、Undo/Redo 模型用例通过；B-09 两条关键 UI 路径通过 | 无稳定复现失败 | 全量 UI runner 未完成；选中隔离、真机旋转/缩放、键盘、自动保存失败恢复仍需稳定全量 UI 与真机证据 |

### 9.3 发布门禁判定

1. **不通过：单元测试必须全绿。** 当前为 110/110 中 1 项稳定失败。
2. **不通过：四套黄金 fixture 不完整。** 未发现规定目录 `artifacts/v2-qa/golden/<fixture>/<template>/<paper>/`，无法证明 20 本自动质量、五模板盲测和双渲染像素指标。
3. **不通过：全量 UI 没有稳定完成。** 长跑 runner 出现 App 未运行、signal kill 与自动重启；三条受影响用例定向复跑通过，只能排除这些局部产品失败，不能替代剩余 UI 用例。
4. **缺证据：真机与外部状态。** 大相册、热降速、后台/进程恢复、PhotoKit 权限变化、StoreKit 真实状态、Share Sheet 和最近 PDF 重启打开均未验收。
5. **通过：构建与核心模型的大部分基础。** 冻结树能够完成测试构建并运行；109 个单元测试以及新增 3 个 v2 契约测试通过。

最终结论：**当前候选版本不满足 Tailor v2 PRD 发布门禁，不能签署“全功能完成”或“可发布”。** 研发需先修复 QA-V2-001 并恢复 110/110 单测；随后在稳定 runner 或真机上完成 UI、GF-01～GF-04、StoreKit、恢复与 PDF 三联验收。

## 10. 第二轮返修复验（2026-07-20 21:50 后）

### 10.1 执行结果

| 批次 | 范围 | 结果 | 证据 |
| --- | --- | --- | --- |
| B-10 | 返修树全量 `TailorTests` | **失败** | 115 tests，113 passed、2 failed，共 424 个断言失败；xcresult：`/tmp/TailorV2Round2QADerivedData/Logs/Test/Test-Tailor-2026.07.20_21-50-28-+0800.xcresult` |
| B-11 | B-10 两条失败用例定向复跑 | **稳定失败** | 2 tests，2 failed，424 failures；xcresult：`/tmp/TailorV2Round2QADerivedData/Logs/Test/Test-Tailor-2026.07.20_21-53-08-+0800.xcresult` |
| B-12 | Book Check、Text、免费 Reader 四条定向 UI | **3 通过、1 失败** | Book Check 精确跳转、文字预设+Undo、7 页免费样章通过；文字白名单路径在换页后未出现面板。xcresult：`/tmp/TailorV2Round2UIQADerivedData/Logs/Test/Test-Tailor-2026.07.20_21-55-51-+0800.xcresult` |
| B-13 | B-12 失败 UI 单独复跑 | **环境/稳定性失败** | runner 在同一路径异常退出并自动重启，重启后 0 tests；不能判为功能通过。xcresult：`/tmp/TailorV2Round2UIQADerivedData/Logs/Test/Test-Tailor-2026.07.20_21-58-23-+0800.xcresult` |

### 10.2 返修项判定

| 验收项 | 判定 | 证据/限制 |
| --- | --- | --- |
| QA-V2-001 主体聚焦 | **通过** | 原失败用例在 B-10 已通过；多图页面已使用 `subjectRegion` 生成非零 `cropOffset`。原缺陷关闭。 |
| 8 字体 token 与旧 token 迁移 | **模型通过，双渲染失败** | `testV2TextFontsExposeExactlyEightPersistedTokensAndMigrateLegacyTokens` 通过；但 `.NewYork-Regular` 被 CoreText 回退为 `TimesNewRomanPSMT`，预览/UIKit/CoreText/PDF 字体身份不能保持一致。 |
| Story Plan 合并/拆分/排序 | **模型通过，UI 缺证据** | 合并、拆分、移动保持照片恰好一次的新增单测通过；没有覆盖 Story Plan 页面完整交互和保存恢复的 UI 证据。 |
| `needsReflow` 与锁页保护 | **模型通过** | 新增单测证明锁定页不会被标记 `needsReflow`；仍缺 UI 标识与后台恢复验收。 |
| Preview/Edit 路由 | **部分通过** | Book Check→精确文字字段通过；文字编辑换页路径出现面板未展示/runner 异常退出，不能签署整体路由稳定。 |
| Book Check 精确返回/忽略持久化 | **通过（模型+局部 UI）** | 精确跳转 UI 通过；仅 suggestion 可忽略且持久化单测通过。 |
| 免费 6–8 页样章 | **通过** | 模型测试通过；UI 实际显示 `PAGE 1 OF 7`，未开放章节不可阅读。 |
| 动态价格接口 | **静态契约通过，商店缺证据** | 生产代码从 StoreKit `Product.displayPrice` 读取并传入购买页；没有真实商品、地区价格、离线/恢复验收。 |
| 无视频入口 | **UI 静态检查通过** | 当前 v2 页面未发现视频按钮或路由；视频导出 service 仍留在容器中但没有用户入口。 |
| Text Edit 稳定性 | **不通过/未关闭** | 定向长跑首次在换页后文字面板未出现，单独复跑在相同流程 runner 异常退出；即使存在模拟器 Accessibility/LLDB 警告，也缺少可重复的通过证据。 |

### 10.3 新增稳定缺陷

| ID | 严重度 | 对应门禁 | 结果 |
| --- | --- | --- | --- |
| QA-V2-002 | P1 | E-004；P-003；预览/PDF 同源渲染 | `systemSerif` 产生系统私有 PostScript 名 `.NewYork-Regular`，随后通过 `UIFont(name:)` / CoreText 重建时被替换为 `TimesNewRomanPSMT`。跨 5 模板、2 纸张及多种文字角色重复出现，导致编辑器、预览和 PDF 字体不能保证一比一。 |
| QA-V2-003 | P1 | E-004；Book Check 文字溢出；P-003 | 文字排版边界测试稳定失败：预期 11/22 行实际 12/24 行，且“增加一个 grapheme 后由恰好容纳变为溢出”的真实排版契约失效。该问题与字体度量回退高度相关，修复后必须同时复验溢出提示和 PDF 分页。 |
| QA-V2-004 | P1 待真机确认 | E-004；Preview/Edit 路由 | 文字编辑从封面返回、切换到照片页再打开 Text 的流程无法取得稳定通过：一次面板不出现，一次 runner 异常退出。需研发补充运行日志并在真机/稳定 simulator 复验；在此之前不能视为仅测试环境问题。 |

### 10.4 第二轮门禁结论

- 已确认返修有效：主体聚焦、Story Plan 模型变更、锁页保护、忽略持久化、7 页免费样章。
- 尚不能进入下一步：全量单测不是全绿，字体和文本溢出存在稳定 P1；Text Edit 路由稳定性没有通过证据。
- PRD/原型仍必须补齐或确认：8 字体的可用字体族/回退规则、Story Plan 逐状态交互、Book Check 忽略后的视觉状态、动态价格加载/失败态、Preview↔Editor 精确返回位置。确认后才能把这些内容作为研发与设计的唯一实施合同。

第二轮最终结论：**QA-V2-001 已关闭，但候选版本仍不满足 Tailor v2 发布及“开始下一步”门禁。**

## 11. 最终冻结版独立复验（2026-07-21 00:00）

> 范围：研发第二轮返修后的冻结工作树。QA 未修改业务代码；只新增 Story Plan 确认摘要 UI 验收用例并更新本账本。

### 11.1 最终执行证据

| 批次 | 范围 | 结果 | 证据 |
| --- | --- | --- | --- |
| B-14 | 全量 `TailorTests` | **通过** | 115 tests，0 failures，38.829s；xcresult：`/tmp/TailorV2FinalRoundQADerivedData/Logs/Test/Test-Tailor-2026.07.20_23-58-19-+0800.xcresult` |
| B-15 | 字体 round-trip、CoreText/grapheme、预览/PDF文字契约、Book Check ignore、Story Plan 模型 | **通过** | 6 tests，0 failures；xcresult：`/tmp/TailorV2FinalRoundQADerivedData/Logs/Test/Test-Tailor-2026.07.21_00-00-16-+0800.xcresult` |
| B-16 | Text Edit ×2：字段白名单/新增可选文字；字体预设/对齐/单次 Undo | **通过** | 2 UI tests，0 failures；此前 QA-V2-004 路径在串行 runner 上稳定完成；xcresult：`/tmp/TailorV2FinalUIQADerivedData/Logs/Test/Test-Tailor-2026.07.21_00-00-38-+0800.xcresult` |
| B-17 | Book Check 精确跳转；Preview logicalPage 横竖屏、目录、奇数尾页、后台恢复 | **通过** | 3 UI tests，0 failures；xcresult：`/tmp/TailorV2FinalUIQADerivedData/Logs/Test/Test-Tailor-2026.07.21_00-01-54-+0800.xcresult` |
| B-18 | Purchase 失败/重试入口、取消、pending、本地化价格、恢复入口 | **通过（Demo StoreKit 边界）** | 2 UI tests，0 failures；失败后仍显示当前本地化价格、Unlock 与 Restore，取消/pending 不授权且编辑保留；xcresult：`/tmp/TailorV2FinalUIQADerivedData/Logs/Test/Test-Tailor-2026.07.21_00-03-49-+0800.xcresult` |
| B-19 | Story Plan 合并确认与影响摘要 | **通过** | 新增 1 UI test，0 failures；确认前明确照片顺序、未锁页复核与锁页保护，确认后显示不丢不重及 `Pages need review`；xcresult：`/tmp/TailorV2FinalUIQADerivedData/Logs/Test/Test-Tailor-2026.07.21_00-04-57-+0800.xcresult` |

### 11.2 缺陷关闭

| ID | 最终状态 | 关闭证据 |
| --- | --- | --- |
| QA-V2-001 主体聚焦 | **关闭** | B-14 中焦点裁切测试通过。 |
| QA-V2-002 字体回退破坏双渲染 | **关闭** | B-14、B-15 中 8 字体持久化/迁移、UIKit/CoreText 可解析、Preview/PDF attributed paragraph 契约均通过。全量日志只在旧 token 迁移辅助路径出现一次 `.SFUI-Regular` 系统提示，正式字体渲染契约没有失败。 |
| QA-V2-003 grapheme 溢出边界 | **关闭** | B-14、B-15 中 11/22 行边界、单 grapheme 触发真实溢出、Unicode round-trip 均通过。 |
| QA-V2-004 Text Edit 路由稳定性 | **关闭（Simulator 自动化范围）** | B-16 串行执行两条核心 Text UI 均通过，覆盖封面返回、换到照片页、再次打开 Text、添加说明文字、保存和 Undo。真机仍需体验验收。 |

### 11.3 门禁判定

| 门禁 | 最终判定 | 边界 |
| --- | --- | --- |
| 115/115 单元测试 | **通过** | 冻结树全量通过。 |
| 字体 round-trip 与双渲染 | **通过** | 自动化覆盖 8 token、旧 token 迁移、UIKit/CoreText、Preview/PDF 共享段落；仍需真机逐字体视觉检查。 |
| CoreText grapheme/溢出 | **通过** | 自动化边界契约通过。 |
| Text Edit 核心路径 | **通过** | 两条定向 UI 通过；键盘、旋转柄与连续字号触控手感仍属真机体验验收。 |
| Book Check 精确返回/忽略 | **通过** | 模型持久化与精确跳转 UI 均通过。 |
| Preview logicalPage | **通过** | 单页/跨页、目录跳转、横竖屏映射、奇数尾页、Home→activate 保持页身份均通过。 |
| Purchase 失败/可重试/本地化价格 | **通过（Mock/UI）** | Demo 本地化价格、失败后重试入口、Restore、cancelled/pending 均通过；真实 App Store 商品、地区价格和无网价格重载仍缺证据。 |
| Story Plan 确认摘要 | **通过** | 模型不丢不重与 UI 确认前/后影响摘要均通过。拆分摘要由同一组件和模型实现，但本轮未新增独立 Split UI 手势用例。 |
| 免费样章、无视频入口 | **通过** | 6–8 页模型及 7 页 UI 已通过；v2 用户流程无视频入口。 |

### 11.4 仅剩外部/人工证据，不再归类为代码门禁失败

1. **真机**：PhotoKit full/limited/denied、万张相册热降速、后台/锁屏/杀进程恢复、文字键盘与旋转/缩放触控、Share Sheet、重启后最近 PDF。
2. **真实 StoreKit**：商品可售状态、不同地区 `displayPrice`、购买/恢复、pending、取消、失败、离线及价格加载失败后的 Retry；当前自动化使用 Demo 服务，不能替代沙盒 Apple ID。
3. **设计盲测**：五模板灰度盲测识别率 ≥80%，以及设计师对字体、排版、节奏和情感品质签字。
4. **黄金样例人工验收**：GF-01～GF-04 的真实照片页、A4/Letter PDF 与运行预览三联像素检查；自动化已经生成确定性 PDF 证据，但不能替代真实内容的视觉评分。
5. **产品质量 KPI**：20 本自动成册中 ≥70% 无需结构重做，需要产品/设计人工打分。

### 11.5 最终结论

**冻结版代码级 QA 门禁通过。** 115/115 单测及本轮 8 条重点 UI 用例全部通过，QA-V2-001～004 均关闭。产品可以进入真机、真实 StoreKit 与设计盲测阶段；但在这些外部证据完成前，QA 仍不签署 App Store 发布结论。

## 12. 2026-07-21 Reader / PDF 实际栅格三联复核

本节更新并收紧 11.5 的结论：115/115 单测证明共享模型与 render-plan 合同成立，但首次实际逐页比较 SwiftUI Reader 与 `LocalPDFExporter` 栅格后，发现合同测试没有捕获的输出差异。因此代码级门禁需重新打开，不能继续沿用“冻结版代码级 QA 门禁通过”的表述作为当前结论。

### 12.1 实测范围

- `Warm Paper`，Letter/A4，各 7 页：cover、dedication、contents、chapterOpener、photoSelection、milestone、closing。
- Reader 由正式 Preview 页面组件逐页截图；PDF 由确定性 fixture 和 `LocalPDFExporter` 生成。
- 纸张边界裁出后统一映射至 A4 `595×842 pt` / Letter `612×792 pt`，按 manifest 元素候选区比较实际栅格 bounding box。
- 完整报告、逐页 metric 与 contact sheet：[triple_render_2026-07-21/REPORT.md](../../../../verification/memorybook_v2/triple_render_2026-07-21/REPORT.md)。

### 12.2 新缺陷

| ID | 等级 | 结果 |
| --- | --- | --- |
| QA-V2-005 | **P0** | Reader/UILabel 与 PDF/Quartz 文字实际布局系统性不一致。A4 文字框偏差 `15.337–85.887 pt`，Letter `11.541–75.016 pt`，违反 P-002/P-003。 |
| QA-V2-006 | **P0** | contents 页 Reader 在页面区域中叠加 `ReaderContentsOverlay`，PDF 无对应元素；这是实际运行合成内容，不是截图裁剪误差。 |

照片几何明显优于文字：A4 最大 `0.769 pt`；Letter 最大 `1.447 pt`（低分辨率 Reader 像素量化下的两像素），但在同一序列化 revision 和高分辨率复验前不签字。Fit/Fill 已覆盖；生产 visual fixture 没有非零 rotation 和有效 zIndex 重叠，二者视觉一致性仍缺证据。

### 12.3 当前门禁结论

**不通过。** 当前不能签署 Final Preview 与 Letter/A4 PDF 一比一，也不能将 GF-01～GF-04 与 20 本质量 KPI 标为已完成。GF-01、GF-03 及 GF-04 的模型零泄漏部分可自动补齐；GF-02 热/内存/恢复、GF-04 权限与缺失 asset、20 本审美和“无需结构重做”评分依赖真机及产品/设计人工验收。

## 13. 2026-07-21 QA-V2-005/006 第二轮复测

第二轮 canonical paper typography 修复后，第一轮 Reader 正文相对 PDF 的明显字号比例错误已经消失；同 serialized revision、连续字号、RTL/emoji/CJK/combining、Fit/Fill、非零 rotation 与重叠 zIndex 均进入真实 fixture。

正式证据见 [三联报告第 7 节](../../../../verification/memorybook_v2/triple_render_2026-07-21/REPORT.md#7-2026-07-21-第二轮-canonical-paper-typography-复测)。原始 metric 与仅全页刚性原点配准后的 metric 分开保留，未做非等比缩放、局部扭曲或逐元素对齐。

| 缺陷 | 第二轮结果 |
| --- | --- |
| QA-V2-005 | **保持 P0 开放**。配准后图片 A4/Letter 最大 0.769/0.723pt；文字仍为 2.307/1.447pt，超过 1pt。 |
| QA-V2-006 | **关闭**。Preview 14 页无纸内 Contents 浮层；FinalPreview 独立 UI 1/1，页面内无 `Reader contents`，页面外 Contents 工具仍可用。 |

运行证据边界必须保留：重型 PDF 与全套同跑曾 SIGKILL；隔离 PDF 1/1、其他 117/117、Reader/FinalPreview UI 2/2 均通过。五模板×双纸张×7 页只完成 PDF 隔离生成；Warm Paper 才有 Reader/PDF 三联，因此不能将其表述为五模板三联签字。

最终门禁仍为：**P-002/P-003 不通过，不能签署预览与导出一比一。**

## 14. 2026-07-21 QA-V2-005/006 第三轮复测

Reader 使用规范 A4/Letter page spec 完成与 PDF 相同的 CoreText shaping/hinting，再对整页一次等比缩放。QA 严格复用冻结脚本和 `≤1 pt` 阈值，仅允许全页刚性原点 registration。

| 缺陷 | 第三轮结果 |
| --- | --- |
| QA-V2-005 | **保持 P0 开放**。配准后图片 A4/Letter 最大 `0.769/0.723pt`；文字收敛至 `1.537/1.447pt`，仍超过 1pt。仅剩 A4 第 3 页标题和 Letter 第 1 页副标题两个单边两像素 raster bbox 差异；无换行、基线或整体几何结构性分歧，但冻结门禁不豁免栅格量化。 |
| QA-V2-006 | **保持关闭**。第三轮未重新引入页面内 Contents 浮层，第二轮 FinalPreview 独立回归证据继续有效。 |

正式证据见 [三联报告第 8 节](../../../../verification/memorybook_v2/triple_render_2026-07-21/REPORT.md#8-2026-07-21-第三轮-canonical-coretext-shaping-复测)，raw、registered metrics、14 张 Reader 证据及 contact sheets 已固化到 `rerun_canonical_v3/`。第三轮完整回归报告为 build、117/117、隔离 PDF 1/1；历史上重型 PDF 与全套同进程曾 SIGKILL，仍不能表述为单次全套通过。

最终门禁仍为：**P-002/P-003 不通过；QA-V2-005 尚未达到关闭条件。**

## 15. 2026-07-21 QA-V2-005 第四轮复测

高分辨率 canonical text raster 修复后的新 Reader 14 页已使用原冻结脚本、同 fixture/revision PDF 与 `≤1 pt` 阈值复算。正式证据见 [三联报告第 9 节](../../../../verification/memorybook_v2/triple_render_2026-07-21/REPORT.md#9-2026-07-21-第四轮高分辨率-canonical-text-raster-复测) 和 `rerun_canonical_v4/`。

| 缺陷 | 第四轮结果 |
| --- | --- |
| QA-V2-005 | **保持 P0 开放**。Registered image A4/Letter 最大 `0.769/0.723pt`；text 最大 `1.538/1.447pt`，仍超过 1pt。 |
| QA-V2-006 | **保持关闭**。本轮没有重新引入 Reader-only contents 浮层。 |

视觉上没有重新出现系统字号、换行或整体基线错位，但 A4 仍有 1 个、Letter 有 4 个可检测文字 bbox 超限；冻结门禁不允许用“肉眼接近”豁免。4 个低对比辅助文字元素/纸型在当前冻结颜色检测器下为 N/D，也未记为通过。

约 2160px 长边离屏 raster 可能带来每页约 12.6 MiB RGBA 缓冲及多页缓存峰值风险；须在真机长书快速翻页、内存警告、后台和 thermal 场景单独验收，不替代本轮几何结论。

第四轮因 Letter 超限文字元素从第三轮 1 个退化为 4 个且增加缓存风险，研发已撤回该实现并恢复第三轮共享 CoreText canonical draw。`rerun_canonical_v4/` 仅保留为失败历史证据；当前最佳证据为 `rerun_canonical_v3/`，A4/Letter 各剩 1 个约 2 Reader pixel 的文字 bbox 残差。**QA-V2-005 仍保持 P0 开放。**
