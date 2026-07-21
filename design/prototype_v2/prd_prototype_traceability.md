# PRD–原型一致性追踪

| PRD 能力 | 原型页面 | 设计来源 | 验收状态 |
| --- | --- | --- | --- |
| 权限、建档、参考照、扫描、确认 | 01–06 | v2_pages_01_06_contract + v2_visual_contract_01_06_18_20 | v2 页面、状态、恢复、视觉层级和数据规则已独立冻结 |
| 自动初稿进度、取消、降级 | 07 | auto-book 01 + detailed 01–02 | 已补失败、人工选择重试、简单时间线降级完成态 |
| Story Plan 与章节语义编辑 | 08 | auto-book 02 + detailed 03–05 | 已补相邻章节合并、事件分割、needsReflow 与锁定页保护 |
| 五模板首次选择 | 09 | auto-book 03 | 已有 |
| 水印样章与 Customize | 10 | auto-book 04 + v1 preview | min(8,total)，正常8/最少6；单时期不虚构拆段，多时期优先两章节 |
| 完整 Page Editor | 11 | editor_v1 + detailed 06–07 | 已补文字选中、中心旋转柄及完整属性面板；图片能力仍沿用 editor_v1 |
| Pages 管理 | 12 | editor_v1 | 已有基础，补锁定与迁移标记 |
| 图片编辑与裁切 | 13 | editor_v1 | 保留并按 v2 手势规则复核 |
| 文字编辑 | 14 | detailed 06–07 | 已按连续字号、8 字体、模板色板/系统颜色、旋转柄、非自动聚焦重出 |
| 页面配方 | 15 | auto-book 05 | 已有 |
| 模板安全应用/重新生成 | 16 | auto-book 06 + detailed 08–09 | 已补默认安全范围、整书二次确认、影响数量和恢复快照 |
| Book Check | 17 | auto-book 07 + detailed 10–12 | 已补通过态、问题精确定位/返回和忽略建议确认 |
| StoreKit 付费与恢复 | 17→18 | v2_visual_contract_01_06_18_20 | 仅当前revision检查通过后进入；本地价格、失败、恢复、返回17均冻结 |
| 已解锁最终预览与导出 | 19 | auto-book 08 | 已增加 Unlocked 标识，与付费门禁一致 |
| 档案继续编辑与最近 PDF | 20 | v2_visual_contract_01_06_18_20 + detailed 13–14 | 已补 checkpoint 恢复、v2副本迁移、旧稿保护和最近PDF丢失/重导 |
| denied 手动导入 | 02→03→04→06 | v2_pages_01_06_contract | PHPicker 3–500张、App私有副本、跳过全库扫描已冻结 |
| 识别代际与旧决策 | 04–06 | v2_pages_01_06_contract + state matrix | generationID含profile+species+references+matcher；embedding复用、stale decision复核已冻结 |
| 敏感照片闭环 | 06 | v2_pages_01_06_contract + state matrix | selected+sensitiveApprovedAt可用；neverUse不可覆盖 |
| 纸型与检查失效 | 09/17/19 | flow/state matrix | 默认Letter、纸型属revision、切换重跑Book Check |
| pre-document恢复 | 03–09→20 | flow/state matrix | 八类Archive checkpoint与动态resumeRoute已冻结 |
| 来源感知返回 | 11/16/18 | flow contract | context stack；编辑后自动复检；issue/page消失使用稳定locator与最近索引fallback |

## v2.2 新增裁决状态资产

- 可审阅 HTML：`design/prototype_v2/v22_adjudication_states.html`
- 状态规范与缺口清单：`design/prototype_v2/v22_adjudication_state_specs.md`
- PNG 总览：`design/prototype_v2/v22-adjudication-overview.png`
- 覆盖：02 denied、04 Manual Import、06 sensitive/stale、09 paper size、17 recheck/fallback、18 only-from-17、20 checkpoints、11/16 ReturnContextStack、单时期 6 页样章。

## P0 结论

- 产品主流程：已确定。
- 新旧功能职责：已确定。
- 未付费/已付费边界：已确定。
- 编辑器保留能力：已确定。
- 自动重排保护：已确定。
- 旧草稿迁移原则：已确定。
- PRD 设计来源：已提供。

本轮列出的 P0 详细视觉状态已经补齐，可作为对应 UI 的实现与验收输入。仍需在工程实现后补充 Dynamic Type、横向安全区、真实键盘和 VoiceOver 的运行态证据；这些属于可访问性与真机验收，不改变当前产品流程。

## 文档产物边界裁决

`07 Smart Draft → StoryPlanDraft`；`08 Story Plan → 确认/编辑 StoryPlanDraft`；`09 Book Style → 首次原子创建 MemoryBookDocument`。已有 v2 文档返回 Story Plan 时不重新创建文档，只更新章节语义并标记相关未锁页 `needsReflow`。

## 详细状态稿入口

- 可审阅 HTML：`design/prototype_v2/detailed_states.html`
- 状态说明：`design/prototype_v2/detailed_state_specs.md`
- PNG 总览：`design/prototype_v2/detailed-states-overview.png`
- 单页：`detailed_states.html?screen=01` 至 `?screen=14`
