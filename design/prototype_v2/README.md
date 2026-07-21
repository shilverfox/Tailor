# Tailor v2 统一原型主文档

> 对应唯一 PRD：`docs/mobile-prd-plans/Tailor_iOS/Tailor_v2_PRD.md`  
> 本文档冻结产品流程、页面职责、跳转和状态；后续视觉细化不得改变这些规则，除非同步修改 PRD 并重新评审。

## 原型由三部分组成

| 原型来源 | 负责范围 | 状态 |
| --- | --- | --- |
| `design/prototype_v1_1.html` 与 `design/reference/v1_1` | Welcome 至 Photo Review、Purchase、Archive 的视觉参考 | 视觉资产复用；产品状态与交互以 v2 合同为准 |
| `design/auto-book-v2/prototype.html` | Smart Draft、Story Plan、Book Style、Book Preview、Layout、Apply Style、Book Check、Final Preview | v2 新增 |
| `design/editor_v1/prototype.html` | Page Editor、Pages、Photo、Text、Layer、Style 等详细编辑状态 | 保留并升级自由文字能力 |
| `design/prototype_v2/detailed_states.html` | Smart Draft、Story Plan、Text、Regenerate、Book Check、Archive 的关键异常/确认/恢复状态 | v2 P0 详细状态基线 |

`prototype_map.html` 是统一入口。上述三个来源不是三个产品方案，而是同一个 v2 主流程的分段视觉资产。

01–06 已由 `v2_pages_01_06_contract.md` 独立冻结；v1 文件仅提供视觉参考，不能反向覆盖 v2 文案、状态、恢复或数据规则。

## 已冻结的融合结论

1. 原生命时间线升级为 Story Plan；原章节标题/说明/封面能力保留在 Story Plan。
2. 原章节九宫格排版不再承担成品编辑；所有成品排版进入 Page Editor。
3. Smart Draft 在 Photo Review 后运行，只消费已确认照片，不重新扫描相册。
4. Book Preview 的 Customize 必须进入完整编辑器。
5. 未购买可完整编辑；Book Preview 开放 `min(8,totalPageCount)` 页带水印样章，正常 8 页、最少 6 页。
6. Book Check 检查整本；无阻断后，未购买进入 Purchase，已购买进入 Final Preview。
7. Final Preview 只用于已购买/恢复/Debug 状态，因此可以直接导出。
8. 五模板切换不能覆盖锁定页面。

## 文档

- `flow_and_screen_contract.md`：20 个页面的入口、动作、跳转和职责。
- `state_matrix.md`：主状态、异常态和恢复行为。
- `prd_prototype_traceability.md`：PRD 与原型逐条追踪。
- `prototype_map.html`：统一可点击入口。
- `detailed_state_specs.md`：14 个 P0 详细状态的交互与视觉验收规则。
- `v2_pages_01_06_contract.md`：01–06 的独立 v2 页面与状态基线。
- `v2_visual_contract_01_06_18_20.md`：由旧稿升级出的 v2 可验收视觉、组件与异常态合同。
- `PRD_PROTOTYPE_FREEZE_2026-07-21.md`：版本、范围、冲突裁决与冻结签字记录。
