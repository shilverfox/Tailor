# Tailor v2 PRD–原型对齐复核

## 结论

产品主流程、原型合同和关键状态稿已对齐，当前无 P0 产品歧义。产品冻结与设计细化门禁均已完成；实现仍须通过代码、测试和运行态视觉验收门禁。

## 已关闭的历史冲突

| 冲突 | 冻结结论 | PRD | 原型合同 |
| --- | --- | --- | --- |
| 自动生成是否替代编辑器 | 不替代；Customize 进入完整 Page Editor | §1、§4.11 | Page 10→11 |
| 原章节编辑器职责 | Story Plan 管语义，Page Editor 管排版 | §4.08、§4.11 | 职责边界 |
| 模板数量 | 5 套 | §4.09 | Page 09 |
| 模板切换是否覆盖编辑 | 锁定页不变；Visual-only 或重排未锁页 | §4.16、§6 | Page 16 |
| 未购买可做什么 | 可完整编辑；只看 6–8 页水印样章 | §1.2、§4.10 | Page 10 |
| 付费门禁位置 | Book Check 后、完整无水印预览/导出前 | §3、§4.17–19 | Page 17→18→19 |
| Final Preview 能否直接导出 | 可以，但只允许已购买/恢复/Debug 进入 | §4.19 | Page 19 Unlocked |
| 文字仅三档字号 | 废止；连续字号 + 8 字体 token + 颜色 | §4.11、§4.14 | Page 14 合同 |
| 图片缩放/旋转方式 | 等比双指缩放，自由旋转，frame 与内容同转 | §4.11、§4.13 | Page 13 合同 |
| 重新生成是否覆盖编辑 | 默认只处理 needsReflow/未锁页，可撤销 | §4.16 | Page 16 |
| 旧草稿怎么办 | 副本迁移、失败回退、不原地覆盖 | §7.2 | Archive/Recovery 状态 |
| 导出后文件在哪里 | 持久 Exports，Archive 可再次打开 | §4.19–20 | Page 20 |
| 完整 MemoryBookDocument 何时创建 | 07 产出 StoryPlanDraft，08 确认，09 首次选模板后原子创建 | §4.07–09 | Page 07→08→09 |
| 01–06 是否仍由 v1 定义 | 否；v2 独立合同定义产品/状态，v1 仅作视觉参考 | §4.01–06 | v2_pages_01_06_contract |
| 纸型与检查何时生效 | 09 默认 Letter 可选 A4；纸型属 revision；19 切换重跑检查 | §4.09、17、19 | Page 09→17→19 |
| 未成册如何恢复 | Archive checkpoint 动态恢复到 03–09 精确页面 | §3.2、§4.20 | Page 20 |
| denied 手动模式 | 04 Manual Import 选3–500张，跳过全库扫描进入06 | §4.01–06 | Page 02→03→04→06 |
| sensitive 是否可入册 | selected+sensitiveApprovedAt 可用；neverUse不可覆盖 | §4.01–06 | Page 06 状态机 |

## 页面覆盖核对

- 01–06：素材获取与确认，以 `design/prototype_v2/v2_pages_01_06_contract.md` 为独立 v2 基线；v1 仅作视觉参考。
- 07–10：Smart Draft、Story Plan、Style、样章预览。
- 11–16：完整编辑器、页面/图片/文字/Layout/安全重排。
- 17–20：Book Check、Purchase、已解锁最终预览、Archive。

页面 ID、进入条件、主操作、返回路径和异常恢复均记录在 `design/prototype_v2/flow_and_screen_contract.md` 与 `state_matrix.md`。

## 已完成的关键状态设计细化

以下内容不再需要产品重新决策，详细状态已输出到 `design/prototype_v2/detailed_states.html` 与 `detailed_state_specs.md`，研发和测试必须以其为实现、验收基线：

1. Smart Draft 失败和简单时间线降级。
2. Story Plan 合并、拆分和 needsReflow 提示。
3. Text Edit 连续字号、字体、颜色和旋转柄。
4. Regenerate 影响确认与恢复快照。
5. Book Check 通过、返回定位和建议忽略。
6. Archive v2 迁移成功、失败与 PDF 丢失。

## 门禁状态

| 门禁 | 状态 |
| --- | --- |
| 主流程明确 | 通过 |
| 页面职责明确 | 通过 |
| 付费边界明确 | 通过 |
| 编辑器能力明确 | 通过 |
| 关键状态和降级口径明确 | 通过 |
| PRD 与原型可追溯 | 通过 |
| 详细视觉状态全部出图 | 通过 |
| 代码影响面和正式 TRD | 通过；见 `03_technical_plan.md` 与 `05_task_breakdown.md` |
| 代码实现验收 | 进行中；以独立设计验收与 QA 账本为准 |
