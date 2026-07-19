# 01–04 v1.1 候选设计参照升格裁决

裁决日期：2026-07-15  
范围：`design/reference/v1_1/` 的 01–04 PNG/SVG 候选稿，与 `Tailor_v1_PRD.md`、`design/visual-qa/ui_scope_contract.md`、`design/visual-qa/reference_manifest.md`、`design/visual-qa/02_ios_pixel_verification_plan.md` 对照。

## 裁决

**不能升格为“像素验收基准（approved）”。**

这些文件可以保留为 `candidate`，用于产品/设计评审和工程布局预研；不得据此把 01–04 的运行截图判为像素 PASS，也不得用它们覆盖仍缺失的 PRD 状态。

| 维度 | 可追溯证据 | 裁决理由 |
| --- | --- | --- |
| 当前登记状态 | `design/visual-qa/reference_manifest.md` 明确写明“当前仓库没有满足 approved 定义的 390×844 视觉参考”；01–04 均为 `candidate`。 | 按既有合同，candidate 不能用于像素 PASS。升格必须经过产品确认，而非由 QA 或工程自行变更。 |
| PRD 对系统 chrome 的规定 | `Tailor_v1_PRD.md` 仅定义 iPhone-only/iOS 17+ 与页面/安全行为，没有状态栏样式、状态栏纳入范围、顶部/底部 safe-area 数值、设备或系统版本。 | 产品层没有可判定的 status-bar/safe-area 视觉口径，不能从 PRD 推导“像素一致”。 |
| 参照稿的系统状态栏 | 01–04 SVG 源均是 `390×844` 画布；从 y=0 开始绘制 App 背景和页面内容，未绘制时间、信号、电量、Dynamic Island/刘海或 Home Indicator，也未附 status-bar mask。 | 参照与真机/模拟器 full-screen 截图不存在一一对应的系统 chrome；状态栏像素不可比较。 |
| 现有验收合同内部缺少闭合参数 | `ui_scope_contract.md` §2 允许“状态栏差异可裁至 app safe-area 后比对”，但未定义 safe-area 的精确矩形、mask 文件或哪个 iPhone/iOS chrome 版本；`02_ios_pixel_verification_plan.md` §4.2 则要求只有同一基线才能比较状态栏，若设计不含则必须由设计师提供 mask。 | 目前没有可执行的统一裁切/mask，因此两个文件的原则不能落地为同一张可复现的像素对比图。 |
| 固定设备/运行环境尚未绑定到候选稿 | 验证计划要求 `Tailor-QA-iPhone13`、390×844@3x、语言/字体/外观与 runtime/build 记录；候选 SVG/PNG 未声明其对应设备、iOS、语言、Dynamic Type、Display Zoom、状态栏策略或导出 hash。 | 即使图像尺寸正确，也不足以保证安全区/字体/系统 chrome 的可重复性。 |
| 01–04 状态覆盖不完整 | `reference_manifest.md` 显示缺 `03-profile-unsupported-species`、`04-references-asset-unavailable`；`ui_scope_contract.md` §3 将这些列为 required reference。 | 不能把有两张主态图等同于页面已具备可验收设计。页面级签收仍 blocked。 |
| 04 的真实素材夹具 | `reference_manifest.md` 为 04-ready 声明 `3 authorized reference PHAsset IDs`；但 `source/04-references-ready.svg` 的三张“照片”是 Sage/Clay/Ink 色块。`ui_scope_contract.md` §2 要求由受控 PHAsset fixture 映射真实本地照片，禁止生成宠物图替代。 | 04-ready 不能作为运行时真实照片网格的高保真比对基准；至少需照片区域 mask 与实际 fixture/crop 合同。 |

## 状态栏与安全区：可判定口径

当前唯一可判定的结论是：**状态栏不应参与 01–04 的像素比较，直到设计交付明确的 app-content mask。**

产品无需在 PRD 中定义运营商、时间或电池百分比；但产品/设计必须在视觉验收合同中确认下列二选一策略：

1. **全屏比较策略**：固定 `Tailor-QA-iPhone13`、iOS runtime、语言、Light mode、Display Zoom、Dynamic Type、状态栏显示规则和截图时刻；设计输出包含同一系统 chrome 的 390×844 PNG。
2. **App 内容比较策略（推荐）**：设计输出 `390×844` reference + 同尺寸 `status-bar-safe-area-mask.png` 或明确矩形（含/不含 bottom home-indicator 的规则）；运行截图只在 mask 允许区域叠图。固定 CTA 仍必须以 iPhone 13 的实际 bottom safe area 验证，不得用裁切掩盖遮挡。

无论采用哪一种，补充规格都应至少冻结：设备型号/逻辑尺寸、iOS runtime、方向、语言、Light/Dark、100% Display Zoom、标准字体、Reduce Motion、状态栏是否进入比较、app-content 顶/底边界、CTA 距底部 safe-area 最小 16 pt。后者已经在 `component_inventory.md` 的 `layout.cta.safeInset` 和 `01-12_acceptance_matrix.md` 中有方向性要求，但尚未绑定到候选 PNG。

## 可升格的最低条件

每个状态（而非整个页面）必须同时满足以下条件，才能由产品将 `candidate` 改为 `approved`：

1. 设计师提交同路径 390×844 PNG、可编辑源和导出版本/hash；修正 04 为受控 PHAsset fixture 或提供照片区域 mask/crop 规则。
2. 产品书面确认该状态的文案、行为、异常处理与 `Tailor_v1_PRD.md` 一致；不得将未覆盖的 required 状态视为 N/A。
3. 产品/设计选择并登记上述一套 status-bar/safe-area 比较策略，补齐可复现 mask 或完整 chrome。
4. `reference_manifest.md` 更新 state、fixture、source、审批人、日期和 SHA-256；`ui_scope_contract.md` 与像素验证计划使用相同矩形/策略。
5. QA 以相同 fixture、设备和 Git revision 留存 runtime、normalized、overlay、diff、metrics；只有此后才可记录 PASS/FAIL。

## 01–04 当前逐状态结果

| 状态 | 当前结论 | 最小补齐项 |
| --- | --- | --- |
| 01 welcome-default / welcome-privacy-sheet | `BLOCKED — DESIGN_BASELINE_CANDIDATE_ONLY` | 产品确认 + chrome/mask 合同 + source/hash。欢迎 editorial 图可保留，因其不作为用户归档照片。 |
| 02 privacy-not-determined / limited / denied | `BLOCKED — DESIGN_BASELINE_CANDIDATE_ONLY` | 产品确认三种权限行为与文案，chrome/mask 合同；随后同 fixture 截图对照。 |
| 03 profile-valid / profile-validation-error | `BLOCKED — DESIGN_BASELINE_CANDIDATE_ONLY` | 同上，且补 `profile-unsupported-species` 和年份关系错误/键盘不遮 CTA 的状态基线。 |
| 04 references-ready / references-under-minimum | `BLOCKED — DESIGN_BASELINE_CANDIDATE_ONLY` | 将 ready 色块替换为受控 PHAsset fixture（或照片区域 mask），补 asset-unavailable、替换/移除状态和 chrome/mask 合同。 |

因此，本轮候选稿**不能**作为产品、设计、研发、测试任何一方的“高保真已验收”证据；可作为下一轮经产品确认后逐状态升格的输入。
