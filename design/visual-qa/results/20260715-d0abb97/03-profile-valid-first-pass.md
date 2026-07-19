# 03 Profile · 第一轮像素审计

审计时间：2026-07-15  
QA 结论：**BLOCKED — DESIGN_REFERENCE_CANDIDATE**  
本报告只记录差异，不构成视觉通过或失败签收。

## 输入与可比性

| 项 | 值 |
| --- | --- |
| PRD/状态 ID | `03 / profile-valid`，fixture `FX-05`（dog / Milo / 2017 / 2024） |
| 设计参照 | `design/reference/v1_1/03-profile-valid.png` |
| manifest 状态 | `candidate`，非 `approved` |
| 运行截图 | `/tmp/tailor-profile-after2-390.png` |
| 设计 SHA-256 | `a75349b703eeda2998d95de1c3b764e48aa75edb58c9a522e12db0f0973a50ec` |
| 运行 SHA-256 | `bebd1e6ab76f68546b40648bcfca73a1c580c2c7363b6512eb9ea62e052381da` |
| Git revision | `d0abb97`（工作树非净，见执行环境） |
| 尺寸 | 两张均为 390×844 PNG |

### 可比区域限制

运行图包含 iPhone 状态栏与 Dynamic Island；candidate 设计图不含状态栏/Home Indicator 的最终定义。根据 `ui_scope_contract.md`，只能对内容区域作方向性审计，不能把原图直接全屏叠加后输出像素分数。

- 原始坐标中，运行图的标题/表单主体比 candidate 约低 55–70 pt；这主要包含约 59 pt 的状态栏安全区差异。
- 底部 CTA 的 safe-area / Home Indicator 基线没有 approved 设计定义，故其与页面底部的距离只能记录为待确认，不能在本轮判定为几何不合格。
- 未生成 overlay/diff 热图：candidate 不符合合同的 approved 参照条件，生成该类产物会造成“已完成像素验收”的误导。

## 方向性视觉差异记录

| 区域 | candidate 观察 | runtime 观察 | 差异/风险 | 优先级 |
| --- | --- | --- | --- | --- |
| 顶部 chrome | 无系统状态栏；返回约 x=29，`PROFILE` 字距较宽且右对齐 | 有状态栏/Dynamic Island；返回约 x=47，`PROFILE` 在右边距处但文字明显更窄 | 缺状态栏规范；eyebrow tracking/字宽不一致，无法实现 1:1 | P0（基线）/P1（文字） |
| 标题 | `Tell us about them.` 约从 y=96 开始 | 同文案约从 y=151 开始 | 扣除状态栏后标题大体接近，但无 approved safe-area 标准，不可判通过 | P0（基线） |
| Species segment | x=24..366，约 48pt 高；Dog selected 区约 x=27..193 | x=24..366，约 53pt 高；Dog selected 区约 x=27..195 | runtime 控件约高 5pt；边角、内边距与选中块比例需以 approved 图确认 | P1 |
| Name field | 约 y=300..352，52pt；标签为次级 Ink | 约 y=369..420，51pt；标签较粗/较深 | 绝对 y 受状态栏影响；字段高接近，但标签 weight/color 方向不同 | P1 |
| Year fields | 两列约 x=24..186、204..366，列间距约 18pt | 两列约 x=23..192、199..367，列间距约 7pt | runtime 半宽字段过宽、列间距小约 11pt；这是独立于状态栏的结构差异 | **P0** |
| Year labels | candidate 为较轻的次级色、常规字重 | runtime 为接近黑色的粗体 | token/排版层级不一致 | P1 |
| Info card | 约 y=482..554，高约72pt；边线和两级文本较克制 | 约 y=548..623，高约75pt；首行更粗、卡片更高 | 扣除安全区后仍有约 7–10pt 垂直/层级差异 | P1 |
| Bottom CTA | x=24..366，约 y=695..752；标题左内边距约23pt | x=24..366，约 y=746..800；标题左内边距约15pt | 宽度一致；左内边距小约8pt。底部距离受缺失 safe-area 基线影响，待 approved 后复验 | **P0**（内边距）/BLOCKED（底部位置） |
| 页面 token | 暖白背景、Ink 主色、纸深输入色、Clay eyebrow | 视觉上背景/Ink/输入色方向相近 | 未做像素采样；candidate 非 approved，不能声称 token 通过 | BLOCKED |
| 文案 | `Milo`、`2017`、`2024`、按钮文案一致 | 与 candidate 一致 | 文案内容可读且一致；字距/字重仍见上述差异 | 记录，不签收 |

## 按合同的逐项判定

| 合同项 | 本轮结果 | 原因 |
| --- | --- | --- |
| approved 390×844 设计 PNG | BLOCKED | manifest 记录 `03-profile-valid` 为 `candidate`。 |
| 同 fixture runtime PNG | PARTIAL | runtime 图片存在且尺寸正确，但截图文件位于 `/tmp`，未落入规范 evidence 目录，且 Git 工作树非净。 |
| 50% overlay / diff / 差异清单 | BLOCKED | 无 approved 基线；不得以 candidate 图生成像素签收产物。本文只保留人工差异清单。 |
| P0 几何 | BLOCKED | 年份双列间距与 CTA 左内边距记录为差异；顶部/底部受缺失 safe-area 基线阻断。 |
| P0 行为状态 | PARTIAL | 仅 valid 静态图；`profile-validation-error` 与 `profile-unsupported-species` 本轮未审计。 |
| 最终结论 | **BLOCKED** | 严格遵循 `ui_scope_contract.md`：candidate 不可用于像素 PASS/FAIL。 |

## 下一步

1. 设计师/产品将 `03-profile-valid.png` 连同状态栏、安全区、CTA 底部规则确认并登记为 `approved`，或替换为 approved 新图。
2. 补齐并批准 `03-profile-validation-error.png` 和 `03-profile-unsupported-species.png`；后者当前为 `MISSING`。
3. 工程按 approved 基线复核：年份双列宽度/间距、year label token、CTA 左内边距、eyebrow tracking。
4. 以冻结的 iPhone 13 fixture 重拍到 `artifacts/visual-qa/<build>/03-profile-valid-runtime.png`，生成 50% overlay、diff 与指标 JSON，再进行第二轮判定。
