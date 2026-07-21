# Tailor v2 原型状态矩阵

| 页面/模块 | Loading | Empty | Success | Failure | Pause/Recovery | 权限/付费 |
| --- | --- | --- | --- | --- | --- | --- |
| Reference Photos | 缩略图加载 | 0–2 张禁用扫描 | 3–5 张可开始 | asset 缺失可重选 | 重启按 localIdentifier 恢复 | 受限相册只显示授权范围 |
| Manual Import | PHPicker 加载 | 少于 3 张不可继续 | 3–500 张直接进入 Photo Review/pending | 单文件读取失败可移除重选 | 保存 App 私有副本；获授权后按指纹映射 PHAsset | denied 专用；不建立全库索引 |
| Scan | 读取总数 | 授权范围无照片 | 进度与候选更新 | 可重试且保留索引 | 暂停、热降速、重启恢复 | 拒绝转手选 |
| Photo Review | 缩略图骨架 | 0 匹配可手选 | 高/待确认/敏感/排除 | 单图失败不阻断全页 | 决策持久化 | 无付费门禁 |
| Smart Draft | 真实生成步骤 | 少于 3 张转回选片 | 产生并持久化 StoryPlanDraft，不创建页面 | 失败展示选择安全、重试/简单时间线降级；不重新扫描 | 取消/稍后继续 | 无付费门禁 |
| Story Plan | StoryPlanDraft 骨架；已有文档时显示章节语义 | 无有效章节转选片 | 首次确认故事规划并进入 Book Style；已有文档编辑章节结构 | 保存失败可重试 | 恢复最后成功版本；已有文档的受影响未锁页标记 needsReflow，锁定页 unchanged | 无付费门禁 |
| Book Style | 模板预览加载 | 模板资源不可用时保留当前选择 | 首次以 StoryPlanDraft + 模板 + 纸型原子创建完整 MemoryBookDocument | 创建失败保留 StoryPlanDraft 并可重试 | 后续模板切换走安全应用/快照恢复 | 无付费门禁 |
| Book Preview | Opening your book | 整书不足8页则显示全部真实页 | 翻页/携 logicalPageID 进入编辑 | 缺 asset 转 Book Check | 回前台及编辑返回保持逻辑页 | 未购买为 min(8,total)，正常8页、最少6页水印 |
| Page Editor | 页面/缩略图骨架 | 无元素显示添加入口 | 完整编辑和自动保存；文字连续字号/8 字体/颜色/中心旋转 | 保存失败/缺 asset/文字溢出 | Undo/Redo、重启恢复 | 无付费门禁 |
| Apply Style / Regenerate | 计算影响 | 无可重排页仅允许 visual-only | 默认只重排 needsReflow + 未锁页；原子应用 | 失败恢复快照 | 一次 Undo；整书重生成二次确认 | 无付费门禁 |
| Book Check | 扫描页面 | 无文档不可进入 | pass/warning/blocking；建议确认后可记录忽略并撤销，阻断不可忽略 | 检查失败可重试 | 携 issueIndex/page/element 定位，返回保留 issue 位置 | 检查整本，不要求购买 |
| Purchase | 商品加载；不显示伪价格 | 商品不可用时禁用购买并可重试/恢复 | 仅从当前revision Book Check通过态进入；展示StoreKit本地化displayPrice | cancelled/failed/offline 保留草稿和位置 | 回17相同通过态；10不可直达 | 只拦最终完整预览/导出 |
| PDF Export | Opening resolved pages | 无可导出照片阻断 | A4/Letter 完成 | 删除临时半成品 | 取消保留草稿 | 已购买/恢复/Debug |
| Archive | 封面骨架/迁移进度 | 空档案入口 | 编辑/Open PDF/Refresh；v1 创建 v2 副本 | 迁移失败可开旧稿；PDF 丢失解释并可重导 | 最近草稿与 PDF 保留 | 购买权益不随档案删除 |

## 关键复合状态

- `PhotoDecision`: decision=`pending/selected/excluded`；sensitivity=`normal/sensitive/neverUse`；sensitive 只有 `selected + sensitiveApprovedAt` 可入册，neverUse 永不可覆盖。
- `ScanGeneration`: embedding 由 asset+extractorVersion 复用；matchGenerationID=hash(profileID+species+referenceSetFingerprint+matcherVersion)，结果键为 generationID+assetID；任一代际字段变化后旧人工 decision 进入 stale、需复核。
- `BookCheckResult`: 绑定 documentRevisionID+paperSize+rulesVersion；任一变化立即失效。
- `ReturnContextStack`: 每帧保存 sourceScreen、logicalPageID/formerPageIndex、paperSize、ruleID+pageID+elementID+formerIssueIndex。16 从11进入时只弹临时帧回11；11保存后先自动复检，blocking→17，否则按稳定locator或最近索引恢复17/19。
- `ArchiveCheckpoint`: profile/reference/scan/review/smartDraft/storyPlan/stylePending/documentReady 八类，主按钮和 resumeRoute 唯一。

## 通用恢复规则

1. UI 不得因 Loading 显示持续白屏。
2. 任何失败不得清空用户照片决策、章节或页面编辑。
3. App 恢复时加载最近成功事务，不自动开始扫描或重新排版。
4. 热状态只降低并发或暂停耗能步骤，必须显示可恢复状态；温度恢复后用户可继续。
5. 所有错误使用可理解文案，不直接展示 `Tailor.ScanFailure error 3` 等内部错误。
