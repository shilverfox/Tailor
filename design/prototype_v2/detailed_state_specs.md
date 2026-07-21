# Tailor v2 详细视觉状态规范

> 视觉源文件：`detailed_states.html`  
> 总览图：`detailed-states-overview.png`  
> 单页查看：`detailed_states.html?screen=01` 至 `?screen=14`

本文冻结 Smart Draft、Story Plan、Text Edit、Regenerate、Book Check 与 Archive 的关键异常、确认和恢复状态。状态稿只能细化交互，不改变 `Tailor_v2_PRD.md` 的主流程与职责边界。

## 状态索引

| 稿号 | PRD 页面 | 状态 | 必须表达的信息 | 主操作 |
| --- | --- | --- | --- | --- |
| 01 | 07 Smart Draft | 生成失败 | 失败原因可理解；112 张选择与所有人工决定安全 | Try again / Use a simple timeline |
| 02 | 07 Smart Draft | 简单时间线降级完成 | 只按日期分章，不推断事件或感受；仍可完整编辑 | Continue to story |
| 03 | 08 Story Plan | 合并章节选择 | 只允许相邻章节；照片保持日期顺序；锁定页不变 | Merge as one chapter |
| 04 | 08 Story Plan | 拆分章节 | 明确分割点、新章节照片数及受影响页面 | Split into two chapters |
| 05 | 08 Story Plan | `needsReflow` | 只标记受影响未锁页，不立即覆盖；锁定页明确 unchanged | Review affected pages |
| 06 | 14 Text Edit | 画布选中与旋转 | 陶土选框；右下旋转柄；文字框和内容共同绕中心旋转 | Drag rotate handle |
| 07 | 14 Text Edit | 完整属性面板 | 连续字号、8 字体 token、颜色；进入不自动弹键盘 | Done |
| 08 | 16 Regenerate | 默认安全重生成 | 只处理 `needsReflow` + 未锁页；影响数量和恢复快照 | Regenerate affected pages |
| 09 | 16 Regenerate | 整书重生成二次确认 | 明确可能丢失的未锁手工编辑；锁定页仍不变 | Confirm destructive scope |
| 10 | 17 Book Check | 全部通过 | revision、纸张、忽略建议记录、进入最终预览 | Continue to final preview |
| 11 | 17 Book Check | 返回具体问题 | 携带 issueIndex/pageID/elementID；修复后回到原问题 | Edit this text |
| 12 | 17 Book Check | 忽略建议 | 只允许 suggestion；展示风险和用户理由；可撤销忽略 | Keep and ignore suggestion |
| 13 | 20 Archive | v1 → v2 迁移中 | 创建副本；旧草稿和 PDF 保持可用；显示实际阶段 | Open original while waiting |
| 14 | 20 Archive | 最近 PDF 丢失 | 文档与照片安全；解释文件缺失；从当前 revision 重导 | Re-export / Open book |

## 交互与文案门禁

### Smart Draft

- 不显示内部错误码。
- 失败页不得用“重新扫描”作为主操作，因为 Smart Draft 不重新执行相册识别。
- `Use a simple timeline` 只使用日期、已确认照片和安全单图/双图配方。
- 降级完成页必须保留进入 Story Plan 和 Page Editor 的完整能力。

### Story Plan

- 合并只支持相邻章节；若选择非相邻章节，禁用主按钮并说明原因。
- 拆分点落在事件组之间；若用户要求拆开同一事件组，先明确将移动的照片。
- 标记 `needsReflow` 后旧页面仍可阅读；只有用户确认布局或执行安全重生成才替换未锁页。
- 锁定页在影响预览中必须显示 `UNCHANGED`，不能只通过弱化颜色暗示。

### Text Edit

- 连续字号建议范围 `8–144 pt`，步进 1 pt；可通过 Slider 与数值输入调整。
- 8 个字体名称与文档 token 一一对应，不以运行时字体枚举替代。
- 颜色面板提供模板色板与系统 Color Picker；颜色值进入共享文档。
- 属性面板打开时输入框不获取 first responder。只有点击正文输入区才弹键盘。
- 旋转柄位于选框右下方至少 24 pt，触控区不小于 44×44 pt；视觉图标可小于触控区。

### Regenerate

- 默认选项永远是安全范围，不预选整书重生成。
- 影响确认至少展示：更新页、锁定不变页、预计页数变化、恢复快照。
- 整书重生成需要二次确认；未勾选风险确认时主按钮禁用。
- 操作整体形成一条 Undo 事务。

### Book Check

- 检查缓存键固定为 `documentRevisionID + PDFPageSize + bookCheckRulesVersion`；纸型或 revision 变化后旧结果立即失效。
- `bookCheckRulesVersion = 1`（独立于PRD版本）：目标打印 PPI `<100` blocking、`100..<200` suggestion；主体安全区保留 `<85%` blocking、`85..<95%` suggestion；同一 nearDuplicateGroup 多张和连续超过 2 页相同配方为 suggestion。
- 09 默认 US Letter、可选 A4；19 切换纸型后必须生成新 revision 并重跑检查，出现 blocking 返回本页。

- 通过态必须显示检查对应的 document revision 与纸张尺寸，避免编辑后沿用旧检查结果。
- 返回编辑器携带 `issueID + pageID + elementID + issueIndex`；返回 Book Check 恢复相同滚动与问题位置。
- 编辑保存产生新 revision 后先自动复检，再以 `ruleID+pageID+elementID` 恢复；问题消失取 formerIssueIndex 附近下一项，无问题显示通过态，绝不复用旧检查结果。
- 阻断项不可忽略。建议项忽略后显示为 `Ignored by you`，保留风险说明与撤销入口。
- Tailor 不替用户改写文字；溢出修复只给字号、框宽或用户自行改文案的选项。

### Archive

- 迁移为 v2 副本，旧数据不原地覆盖；迁移完成并验证保存前不得标记完成。
- 迁移失败时提供 `Try migration again` 与 `Open original`，不删除旧草稿。
- 最近 PDF 丢失不等于文档丢失。文案要区分 App 内 Exports、外部 Files 副本和可编辑文档。
- 重导使用当前文档 revision；若用户希望复现旧 PDF，应先说明旧 revision 是否仍有快照。

## 视觉验收要点

1. 所有状态均使用 Tailor 暖白、深绿、陶土橙体系；错误使用克制砖红，不使用系统大面积警告红。
2. 每个确认态必须同时展示“会改变什么”和“不会改变什么”。
3. 锁定、迁移、忽略和恢复不能只靠颜色表达，必须有文字标签或图标。
4. 页面标题、状态标签、主操作的阅读顺序在 390×844 pt 画布上完整可见。
5. Dynamic Type 放大后，底部主按钮不得覆盖关键影响信息；实际 SwiftUI 页面需要滚动容器与安全区验证。
