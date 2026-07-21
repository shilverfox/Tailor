# Tailor v2.2｜WP-1 / WP-2 设计验收矩阵

> 冻结基线：`Tailor-v2.2-docfreeze-2026-07-21`  
> 设计参考：`../v22_adjudication_states.html?screen=01` 至 `?screen=12`  
> 状态规范：`../v22_adjudication_state_specs.md`  
> 用途：研发自验、设计验收与 QA 截图取证。本文不新增产品能力，不改变冻结页面、状态、路由、付费或恢复行为。

## 1. 使用边界

- **WP-1 数据契约与迁移**负责让画面中的 checkpoint、revision、paperSize、match generation、stale decision、sensitive approval、manual asset 和 ReturnContextStack 有可恢复的数据事实；仅出现 UI 不算通过。
- **WP-2 03–09 主流程事务**负责 Manual Import、03–09 checkpoint、StoryPlanDraft 边界及 09 原子创建完整文档。WP-2 不得用临时页面状态替代 WP-1 持久化。
- 12 个状态是同一冻结方案的设计验收基线。状态 01、02、05、09 是 WP-2 直接交付面；其余状态主要验证 WP-1 契约能否被后续工作包正确消费，**不得据此把 WP-3～WP-5 标记为 WP-2 已完成**。
- 验收时以冻结 PRD 和状态规范为语义真源；HTML 中的具体示例数字、宠物名、revision、页码与 `$19.99` 仅是 fixture。购买页实际金额必须来自 StoreKit `displayPrice`。
- 每张运行截图必须完整包含状态栏、导航区、主体状态和底部操作区；不得只截局部控件。动态结果还须附对应 xcresult、日志或持久化断言，但这些不替代截图。

## 2. 截图证据命名

统一目录建议：`artifacts/v22-implementation-review/<build>/<device>/`。

```text
WP12-V22-S<稿号>-P<页面>-<状态>-<变体>-390x844.png
```

- `<稿号>`：`01`～`12`，与 HTML 的 `?screen=` 一致。
- `<页面>`：两位页面号；跨页状态使用 `P11-16-11`。
- `<状态>`、`<变体>`：只用小写英文和短横线，例如 `manual-import-under-min`。
- 同一状态存在 enable/disable、成功/失败或返回分支时，分别留图，不得用一张图口头说明。
- 原型基准截图可加 `-reference`；App 运行截图加 `-actual`；二者不得覆盖同名文件。

## 3. 12 个新增状态验收矩阵

| 稿号 / 工作包 | 页面与状态 | 进入条件 | 必须可见元素 | CTA enable / disable | 返回路径 | 错误 / 恢复态 | 截图证据命名 |
|---|---|---|---|---|---|---|---|
| **S01**  WP-1：manual mode；WP-2：直接交付 | **02 Privacy**：权限拒绝后的 Manual route | 系统 PhotoKit 状态为 `denied`；用户仍处于新建档案流程 | `Access denied`；“不会后台扫描”；PHPicker 只返回明确选择文件；`Choose 3–500 photos`；私有保存及随档案删除说明；`Import photos manually`；`Open Settings instead` | `Import photos manually` 在 denied 状态可用；不得出现或启用全库扫描 CTA；Settings 可用 | 主 CTA 先进入 03，完成 profile 后进入 04 Manual Import；Settings 返回仍停留 02 并重新读取真实权限；返回键回 01 | 权限仍 denied 时不能伪装为 limited；重新授权后按正常授权路径继续，不丢已保存 profile/checkpoint | `WP12-V22-S01-P02-permission-denied-manual-route-default-390x844-actual.png`；`...-settings-return-denied-...png`；`...-settings-return-authorized-...png` |
| **S02**  WP-1：manual asset / private copy；WP-2：直接交付 | **04 Manual Import**：3–500 张与私有副本 | 02 denied 路径完成 03 后进入；PHPicker 返回用户明确选择的最终候选 | `已选择 / 500` 计数；选中缩略图；最少 3 张/上限 500；仅复制所选原图；删档清理；授权后指纹映射说明；“直接进入 Needs review、不运行全库扫描” | `0–2` 张时 `Review selected photos` 禁用并说明还差数量；`3–500` 张启用；500 张时 Add 禁用或阻止第 501 张并显示上限；读取失败项不得计入可继续数量 | 主 CTA 直接进入 06，绝不经过 05；Add more 留在 04；返回 03；Save for later（若呈现）进入 20 并保留选择 | 文件读取失败显示可移除/重选，已成功选择及副本不丢；重启后恢复计数和缩略图；后续授权映射成功项删除私有副本、未映射项继续可用 | `WP12-V22-S02-P04-manual-import-under-min-disabled-390x844-actual.png`；`...-three-enabled-...png`；`...-five-hundred-limit-...png`；`...-read-failed-recoverable-...png`；`...-cold-resume-...png` |
| **S03**  WP-1：approval fields；后续 WP-3 消费 | **06 Review**：Sensitive 显式批准 | 用户从 06 打开 `sensitive` 且尚未批准的照片详情；`neverUse` 不得进入此普通批准态 | 照片预览；`Sensitive · not included`；克制风险说明；明确的用户确认控件；Pending/未批准状态；`Include this photo` 与 `Keep it out` | 未完成明确确认时 Include 禁用；确认后启用；提交时同一事务写入 `decision=selected + sensitiveApprovedAt`；neverUse 永远不出现可用批准 CTA | 成功或 Keep it out 均回 06 原筛选/滚动位置；取消不改变原 decision | 保存失败留在详情并保留用户当前选择、允许重试；取消/失败不得写批准时间；冷恢复仍以持久化事实显示是否已批准 | `WP12-V22-S03-P06-sensitive-approval-pending-disabled-390x844-actual.png`；`...-acknowledged-enabled-...png`；`...-save-failed-...png`；`...-never-use-no-bypass-...png` |
| **S04**  WP-1：generation / stale；后续 WP-3 消费 | **06 Review**：新匹配代与 stale choices | species、参考照集合或 matcherVersion 改变，创建新 generation；旧人工 decision 存在 | 变化原因；新 generation 可理解标识；stale 总数；旧照片只读/降饱和；`REVIEW AGAIN`；“旧选择仅供参考、复核前不入册”；已确认/待确认统计 | stale 数量 `>0` 时 `Review N stale choices` 启用；逐张和批量重审可达；未重审 stale 不得被 Create/入册旁路；无 stale 时不显示虚假重审 CTA | 重审进入 06 的 stale 过滤结果；Save for later→20 checkpoint；返回仍回 06 总览且保留新 generation | 重匹配失败不得把旧 decision 当成当前有效结果；恢复后继续同 generation 与未完成复核；姓名/年份变化不得错误触发此页 | `WP12-V22-S04-P06-stale-decisions-summary-390x844-actual.png`；`...-batch-review-...png`；`...-rematch-failed-no-inherit-...png`；`...-cold-resume-...png` |
| **S05**  WP-1：revision/paper；WP-2：直接交付 | **09 Book Style**：模板 + 纸型共同创建首个 revision | StoryPlanDraft 已确认，尚无 MemoryBookDocument；从 08 或 20 `Choose style` 进入 | 五模板入口；当前模板预览；纸型同页选择；US Letter 默认且标明默认；A4 尺寸；模板+纸型共同创建首个完整 revision 的说明 | 只有 StoryPlanDraft 有效且模板、纸型均有有效选择时 `Create first draft` 启用；创建事务进行中禁用防重复；默认未改纸型即 Letter；显式选 A4 时不得先建 Letter 再替换 | 成功原子创建唯一 MemoryBookDocument 后进入 10；Back→08；Save for later→20/stylePending checkpoint | 原子创建失败停留 09、保留选择且不产生半成品/第二套文档，可重试；冷恢复回 09 并恢复当前模板/纸型选择 | `WP12-V22-S05-P09-style-paper-letter-default-390x844-actual.png`；`...-a4-selected-...png`；`...-creating-disabled-...png`；`...-create-failed-retry-...png`；`...-checkpoint-resume-...png` |
| **S06**  WP-1：revision/check key；后续 WP-4 消费 | **17 Book Check**：19 切纸型后的复检 | 已在 19 且当前 revision/Letter 已通过；用户切到 A4，生成新 revision 并自动检查 | 新纸型 A4；新 revision；真实检查百分比/页数；规则分类进度；blocking/suggestion/pass 状态；`Final Preview stays hidden` | 检查期间唯一底部 CTA 禁用并显示进度；不得启用预览/导出；完成后有 blocking 才允许 Review/Fix，0 blocking 才允许进入 19 | blocking→17 并定位问题；无 blocking→19/A4；返回不得闪现旧 Letter Final Preview | 检查失败时不能复用旧三元组结果，也不能展示新纸型 Final Preview；保留新 revision 并提供既有 Book Check 恢复/重试路径 | `WP12-V22-S06-P17-paper-change-recheck-running-390x844-actual.png`；`...-blocking-result-...png`；`...-passed-to-p19-a4-...png`；`...-check-failed-no-old-preview-...png` |
| **S07**  WP-1：stable locator / former index；后续 WP-4 消费 | **17 Book Check**：编辑保存后的稳定 issue fallback | 从 17 某 issue 进入 11；保存形成新 revision；自动复检完成；旧 locator 消失或元素/页面被删 | 新 revision 已检查；旧 locator 已解决；下一有效 issue 的 rule/page/element 信息；former index fallback 说明；无旧 revision 闪现 | 存在下一 issue 时 `Continue review` 启用并定位它；同 locator 仍存在时优先定位同 issue；无 issue 时显示 pass summary，后续 CTA 按购买状态走 18/19 | 返回顺序固定：同 locator → `min(formerIndex,lastIndex)` 附近问题 → pass summary；不得引用旧 issue 对象 | 自动复检失败不恢复旧检查 UI；保留编辑 revision 和返回上下文，停在检查恢复态；页面/元素删除使用同一 fallback | `WP12-V22-S07-P17-stable-fallback-next-issue-390x844-actual.png`；`...-same-locator-...png`；`...-pass-summary-...png`；`...-recheck-failed-no-stale-result-...png` |
| **S08**  WP-1：passed context；后续 WP-4 消费 | **18 Purchase**：只从当前 revision 的 17 通过态进入 | 当前 `revision + paper + rulesVersion` 无 blocking，用户未购买，从 17 Continue 进入 | `BOOK CHECK PASSED`；当前 revision；纸型；无阻断；完整无水印交付/A4+Letter/永久本地保存/可重复导出；StoreKit 本地化价格；Restore；Cancel 返回 Book Check | 商品加载时购买 CTA 禁用且不显示伪价格；商品可用后启用；离线/不可用/加载失败时禁用并显示 Retry + Restore + Back；不得从 10 或 deeplink 绕入 | 购买/恢复成功→19 同 revision/paper；取消、购买失败、恢复失败、离线→17 同一通过态及滚动位置；不得回 10 | 所有失败保留草稿且不授予权益；恢复失败可重试；后续编辑/切纸型虽保留权益，但必须重新 Book Check | `WP12-V22-S08-P18-purchase-ready-localized-price-390x844-actual.png`；`...-product-loading-disabled-...png`；`...-offline-retry-...png`；`...-cancel-return-p17-pass-...png`；`...-success-p19-same-revision-...png` |
| **S09**  WP-1：八类 checkpoint；WP-2：03–09 直接交付 | **20 Archive**：checkpoint 与动态 CTA | 档案存在且其唯一当前 checkpoint 为八类之一；从启动或“稍后继续”进入 20 | 档案卡一次只突出一个当前阶段；对应保存摘要；唯一动态主 CTA；规范总览映射为 profile/reference/scan/review/smartDraft/storyPlan/stylePending/documentReady | 动态 CTA 固定映射：`Continue profile`→03；`Choose photos`→04；`Resume scan`→05；`Review photos`→06；`Continue draft`→07；`Review story`→08；`Choose style`→09；`Continue editing`→10。不得同时提供多个竞争主 CTA | 点击主 CTA 只打开 checkpoint 的唯一 resumeRoute，并恢复该页已保存状态；返回 Archive 后仍显示最新 checkpoint | 依赖数据失效时只回退到最早需修复页面，保留仍有效的 profile、decision、document/导出快照；scan 恢复不得从 0 自动重扫 | `WP12-V22-S09-P20-checkpoint-profile-390x844-actual.png` 至 `...-document-ready-...png` 共八张；另存 `...-invalid-data-earliest-fallback-...png` 与 `...-scan-resume-progress-...png` |
| **S10**  WP-1：ReturnContextStack；后续 WP-4 消费 | **11→16→11**：嵌套返回上下文 | 从 10/17/19 携 logical page、paper 及可选 issue locator 进入 11，再由 11 打开 16 | 来源提示（如 `Style for page 12`）；Style 临时帧；底层 Preview/Check/Final context 仍可见或可验证；Visual style only / Rearrange unlocked pages；影响范围；Apply 与 Cancel | 有合法互斥选项和可执行差异时 Apply 启用；执行中禁用；Cancel 始终只关闭临时 Style 帧；不得让 16 直接跳回底层 10/17/19 | Apply/Cancel 均先回 11 同 logical page；离开 11 后才消费底层帧：10→10，同 issue 的 17→自动复检，19→自动复检 | Apply 失败不得消费任何 stack frame或改变底层 return target；保留 Editor 状态并可重试；冷恢复后栈顺序不倒置 | `WP12-V22-S10-P11-16-11-context-stack-from-p10-390x844-actual.png`；`...-from-p17-...png`；`...-from-p19-...png`；`...-cancel-back-editor-...png`；`...-apply-failed-stack-preserved-...png` |
| **S11**  WP-1：new revision / return target；后续 WP-4 消费 | **11→Check→17/19**：保存后的自动复检中间态 | 11 的底层来源为 17 或 19；用户保存产生新 revision 并离开 11 | `CHECKING LATEST EDITS`；新 revision；原纸型；真实检查进度；明确 return target；`blocking→17 / no blocking→19`；“旧预览不显示” | 检查期间无可绕过 CTA，底部进度按钮禁用；不得 Back 到旧 17/19；完成后由结果自动路由 | 17 来源：按稳定 locator/fallback 回 17；19 来源：blocking→17，pass→19 原 logicalPageID，删除则 formerPageIndex 最近页，再无则第 1 页 | 检查失败时留在最新 revision 的恢复/重试状态，不展示旧 pass 或旧 Final Preview；本文不新增独立错误页样式，验收重点是不绕过与不闪旧内容 | `WP12-V22-S11-P11-auto-recheck-running-from-p17-390x844-actual.png`；`...-from-p19-...png`；`...-blocking-to-p17-...png`；`...-pass-to-p19-logical-page-...png`；`...-failed-no-old-preview-...png` |
| **S12**  WP-1：可恢复 SamplePlan 输入；后续 WP-5 消费 | **10 Book Preview**：单一时期、3 张、真实 6 页样章 | 仅 3 张 eligible 照片且属于同一真实时期；未购买；文档真实总页数允许最少 6 页 | `SAMPLE · 6 PAGES`；单一真实时期说明；六页固定族：Cover、Contents、真实 Dedication/Note、唯一真实 Chapter opener、真实 Photo page、Closing；每页水印；不得出现第二虚构章节/重复照片/虚构日期事件感受 | 六个真实样章页成功解析时 `Customize sample` 启用；用户只能打开这 6 页带水印内容，整书轨道可见但未开放页不可读；不能以复制照片凑页 | Customize→11 当前样章逻辑页；Back to story→08；11 返回恢复同 logicalPageID；Check book 仍遵循 10→17，不直达 18 | 某真实素材不可用时不得以虚构页/重复照片补位；按既有缺失素材/Book Check 流程修复。样章不足冻结真实结构时不宣称该状态通过 | `WP12-V22-S12-P10-single-period-six-page-sample-390x844-actual.png`；`...-page-watermark-open-...png`；`...-no-second-chapter-structure-...png`；`...-missing-asset-no-fabrication-...png` |

## 4. WP-1 / WP-2 交验判定

### WP-1 可以签署的条件

1. S01～S11 所引用的数据事实均来自持久化模型/迁移后的真实记录，而非只存在于 View state。
2. 冷启动后 manual asset、checkpoint、generation/stale、sensitive approval、revision/check key 和 ReturnContextStack 的显示与保存前一致。
3. 数据失效时严格执行表内 fallback；不静默继承旧 decision、旧 Book Check 或旧 Final Preview。
4. 对应模型/文件自动化证据与截图中的 ID、数量、paper、revision、route 一致。

### WP-2 可以签署的条件

1. S01、S02、S05、S09 的直接交付面全部通过；特别是 denied→03→04 Manual Import→06 不经过 05。
2. 03–09 每一步均写入唯一 checkpoint；进程终止后从 20 动态 CTA 精确恢复，不自动重扫或重建已成功阶段。
3. 07 只持久化 StoryPlanDraft、08 只编辑/确认它；09 才以 `StoryPlanDraft + style + paper` 原子创建唯一完整文档。
4. 09 创建失败不产生半成品；成功后进入 10，且纸型和 revision 与 S05 截图及持久化断言一致。

### 不得据此提前签署

- S03、S04 的四层 eligibility/识别重匹配属于 WP-3 完整交付。
- S06～S11 的 revision gate、付费链、嵌套返回和自动复检属于 WP-4 完整交付。
- S12 的样章算法与 Debug 隔离属于 WP-5 完整交付。
- 设计截图通过不替代 `AUTO-UNIT/AUTO-FILE/AUTO-UI`、真机 PhotoKit、StoreKit 沙盒、Release 隔离、`QA-V2-005` 或最终 Preview/PDF 三联验收。

## 5. 设计签字模板

```text
Build / Commit:
Device / iOS:
Fixture / Archive ID:
Reviewed states:
Reference screenshots:
Actual screenshots:
P0 visual/behavior mismatch:
P1 visual/behavior mismatch:
WP-1 decision: PASS / FAIL / NOT READY
WP-2 decision: PASS / FAIL / NOT READY
Designer:
Developer self-check:
QA witness:
Date:
Notes:
```
