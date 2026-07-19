# Tailor v1.1 · 05–12 候选设计基准出图计划

状态：设计生产计划；不代表任何页面已经通过产品或 QA 签收。  
权威规则：PRD → `design/detailed/v1_1_design_delta.md` / `ui_spec.md` → `design/visual-qa/ui_scope_contract.md` → 本计划。  
明确排除：`design/screens/01.png`–`12.png`、`prototype.html` 及其截图均不可作为本计划的输入或像素基线。

## 统一出图与叠图规范

| 项目 | 固定规范 |
| --- | --- |
| 输出 | 每个状态输出一张 `390×844 px` PNG，路径 `design/reference/v1_1/<page>-<state>.png`。 |
| 可编辑源 | 同名 SVG/设计源置于 `design/reference/v1_1/source/`；源内必须写明 fixture ID、状态 ID 和设计版本。 |
| 系统 chrome | 参考 PNG 包含 Tailor 自己的顶部导航与底部安全区间距；不把真实时间、信号、岛区、浏览器边框作为像素验收项。QA 以 app safe-area 内的 `390×844` canvas 对齐。 |
| 内容 mask | `PHAsset` 位置用 `PHAssetMask`：只校验容器 x/y/宽高、圆角、aspect-fill、状态徽章、遮罩与文案；不校验用户实际照片像素。非照片文字、颜色、CTA、卡片、图标、间距全部参与叠图。 |
| fixture | 同一个 fixture 在 Confirmation → Timeline → Chapter → Preview → Export 中保持 asset ID 与资格状态。fixture 仅记录匿名 ID/日期/状态，不存原图副本。 |
| 图层命名 | `chrome`, `content`, `bottom-action`, `modal`, `phasset-mask`, `redaction`；所有 source 必须可单独隐藏 `phasset-mask`，供无敏感图的设计评审。 |

## 受控 fixture 套件

| ID | 数据 | 用途 |
| --- | --- | --- |
| FX-09 | `scan-set-A`：4,281 个授权资产；12 个候选；已处理 1,426；likely 39 | 05 running/paused/interrupted/low-battery/failed/complete。缩略图为 runtime mask。 |
| FX-10 | `review-set-A`：High selected 2、Needs review 110、Sensitive 3、Excluded 16、Never use 1 | 06 主确认全链路；Milo 为显示名。 |
| FX-11 | `review-zero`：0 个清晰候选；3 个参考照仍可用 | 06 zero match 与手动选择/保留草稿。 |
| FX-12 | `timeline-set-A`：2018–2019 4 张、2021 3 张、2023 2 张；2021 为隐藏候选 | 07/08/09/11 的普通时间线、隐藏期、两时期样章。 |
| FX-13 | `timeline-range-hidden`：2021-05-01 至 2021-12-31 的 3 张 selected，跨一个章节 | 07 日期范围隐藏的影响摘要与章节 `Some photos hidden`。 |
| FX-14 | `chapter-empty`：唯一章节的唯一封面被移除/neverUse 后为空 | 08 空章节、cover updated、Add photos/Delete chapter。 |
| FX-15 | `preview-one-period`：仅 2019 一个可见时期、2 张 selected | 09 素材不足解释页；不得复制照片凑页。 |
| FX-16 | `preview-two-period`：两个可见时期，各 4 张 selected；一条用户 note | 09 正常 7 或 8 页水印样章、11 PDF。 |
| FX-17 | `archive-set-A`：Milo exported PDF、Nori draft scanning、一个被撤销访问档案 | 12 populated/access revoked/rescan。 |

## 05 — On-device scan

| PNG 状态 | fixture | 必须呈现 | mask / 可编辑源 |
| --- | --- | --- | --- |
| `05-scan-running.png` | FX-09 | Ink full canvas、180pt ring、当前检查/匹配数、4 个 local thumbnail mask、Pause、固定本机处理说明 | `05-scan-running.svg`; 缩略图 38×38 `PHAssetMask`。 |
| `05-scan-paused.png` | FX-09 | `Scan paused at 62%`、进度已保存、Resume scan | `05-scan-paused.svg`; 无自动恢复或通知 UI。 |
| `05-scan-interrupted.png` | FX-09 | 用户主动打开档案后的 `Ready to continue where you left off.`、Resume | `05-scan-interrupted.svg`; 不能出现通知来源或倒计时。 |
| `05-scan-low-battery.png` | FX-09 | 非诊断性警示卡、Pause now / Continue later | `05-scan-low-battery.svg`; 系统电量图标不参与像素对照。 |
| `05-scan-failed.png` | FX-09 | ErrorCard、Try again、Review matches so far、确认内容仍在 | `05-scan-failed.svg`; 不显示照片自动弹出。 |
| `05-scan-complete.png` | FX-09 | Matches ready、Review photos；无自动推进截图 | `05-scan-complete.svg`。 |

## 06 — Photo confirmation

| PNG 状态 | fixture | 必须呈现 | mask / 可编辑源 |
| --- | --- | --- | --- |
| `06-review-high-with-pending.png` | FX-10 | 4 状态标签+图标+数、All years、可见 `Review photos` 进度卡、Create timeline | `06-review-high-with-pending.svg`; 3 列 `PHAssetMask`。 |
| `06-review-needs-review.png` | FX-10 | Needs review 已选态、明确“Tap a photo to decide” | `06-review-needs-review.svg`。 |
| `06-review-viewer.png` | FX-10 | aspect-fit 原图 mask、日期/状态、This is/Not/Set aside 三个至少48pt动作 | `06-review-viewer.svg`; viewer 不显示诊断标签。 |
| `06-review-pending-gate.png` | FX-10 | selected/pending 计数、Review primary、Create with selected secondary、Cancel | `06-review-pending-gate.svg`。 |
| `06-review-sensitive.png` | FX-10 | 保护卡、敏感缩略图/日期、无病情/临终标签 | `06-review-sensitive.svg`; `PHAssetMask`。 |
| `06-review-never-use-confirm.png` | FX-10 | 破坏性二次确认与“原图留在 Photos”影响说明 | `06-review-never-use-confirm.svg`。 |
| `06-review-never-use-manager.png` | FX-10 | 折叠管理展开、40% 模糊缩略图 mask、Allow in this archive | `06-review-never-use-manager.svg`。 |
| `06-review-excluded.png` / `06-review-year-filter.png` / `06-review-zero-match.png` / `06-review-batch.png` | FX-10/FX-11 | Restore、年份 sheet、三条零匹配退出路径、批量排除/加入/搁置 | 四个同名 source。 |

## 07 — Life timeline

| PNG 状态 | fixture | 必须呈现 | mask / 可编辑源 |
| --- | --- | --- | --- |
| `07-timeline-visible.png` | FX-12 | 年份轴、3–6 章节卡、72×72 cover mask、菜单、Preview CTA | `07-timeline-visible.svg`。 |
| `07-timeline-edit-periods.png` | FX-13 | A year / Custom dates、日期校验、无照片预览 | `07-timeline-edit-periods.svg`。 |
| `07-timeline-hide-confirm.png` | FX-12 | Hide this period? 影响说明、Hide period/Cancel | `07-timeline-hide-confirm.svg`。 |
| `07-timeline-hidden-collapsed.png` | FX-12 | Hidden periods (n)；日期/标题/数量，仅文字、无封面 | `07-timeline-hidden-collapsed.svg`; 禁止 `PHAssetMask`。 |
| `07-timeline-hidden-expanded.png` | FX-12 | Restore to album；恢复前不加载封面 | `07-timeline-hidden-expanded.svg`; 禁止 `PHAssetMask`。 |
| `07-timeline-range-impact.png` / `07-timeline-empty.png` | FX-13 / FX-14 | Some photos hidden；空章 Add photos/Delete chapter | 两个同名 source。 |

## 08 — Chapter editor

| PNG 状态 | fixture | 必须呈现 | mask / 可编辑源 |
| --- | --- | --- | --- |
| `08-chapter-editor.png` | FX-12 | 年份、标题、optional note、3 列照片、单一封面徽章、排序提示 | `08-chapter-editor.svg`; 9 个 `PHAssetMask`。 |
| `08-chapter-cover-actions.png` | FX-12 | Set as cover/Move/Remove，非系统照片删除 | `08-chapter-cover-actions.svg`。 |
| `08-chapter-empty.png` | FX-14 | 空占位、Add photos/Delete chapter、无封面 mask | `08-chapter-empty.svg`。 |
| `08-chapter-dirty-exit.png` / `08-chapter-save-failed.png` | FX-12 | Keep editing/Save and return/Discard；保存失败保留输入 | 两个同名 source。 |

## 09 — Preview

| PNG 状态 | fixture | 必须呈现 | mask / 可编辑源 |
| --- | --- | --- | --- |
| `09-preview-unpurchased-page-1.png` … `09-preview-unpurchased-page-8.png` | FX-16 | 5:7 分页、封面/目录/两时期 opener+selection/可选 note/closing；每页 `TAILOR · PREVIEW` 原生文字水印 | 8 个 source；照片区域使用 `PHAssetMask`，不得用生成宠物图。 |
| `09-preview-insufficient.png` | FX-15 | 一期/素材不足说明页，不复制照片、不虚构内容 | `09-preview-insufficient.svg`。 |
| `09-preview-loading.png` / `09-preview-failed.png` | FX-16 | paper skeleton + Preparing；ErrorCard Try again/Return | 两个同名 source。 |
| `09-preview-purchased.png` | FX-16 | 同内容无水印、Generate full PDF | `09-preview-purchased.svg`。 |

## 10 — Purchase

| PNG 状态 | fixture | 必须呈现 | mask / 可编辑源 |
| --- | --- | --- | --- |
| `10-purchase-default.png` | FX-16 | 交付清单、$19.99、One-time、隐私、恢复、法律文案 | `10-purchase-default.svg`；无宠物图。 |
| `10-purchase-purchasing.png` | FX-16 | 固定56pt loading CTA、禁重复触发 | `10-purchase-purchasing.svg`。 |
| `10-purchase-cancelled.png` / `10-purchase-failed.png` / `10-purchase-restored.png` | FX-16 | 中性取消、ErrorCard retry/restore/back、恢复确认 | 三个同名 source；不得含情绪催促。 |

## 11 — Export

| PNG 状态 | fixture | 必须呈现 | mask / 可编辑源 |
| --- | --- | --- | --- |
| `11-export-page-size.png` | FX-16 | A4/US Letter compact sheet | `11-export-page-size.svg`。 |
| `11-export-rendering.png` | FX-16 | `Rendering page 4 of 18`、本机处理、可在 app 打开后继续 | `11-export-rendering.svg`; PDF cover 用 `PHAssetMask`。 |
| `11-export-complete.png` | FX-16 | PDF cover thumb、Save and share PDF、Return、备份提示 | `11-export-complete.svg`; 实际分享 sheet 不作为 Tailor 像素图。 |
| `11-export-failed.png` / `11-export-file-unavailable.png` | FX-16 | 错误+Try again/Return；Generate again 原因 | 两个同名 source。 |

## 12 — Archives and settings

| PNG 状态 | fixture | 必须呈现 | mask / 可编辑源 |
| --- | --- | --- | --- |
| `12-archives-populated.png` | FX-17 | 多档案 card、72×72 local cover mask、rescan/access/about/delete | `12-archives-populated.svg`。 |
| `12-archives-empty.png` | FX-17（删除后） | 空档案文案与 Create CTA | `12-archives-empty.svg`。 |
| `12-archives-access-revoked.png` | FX-17 | 每档案权限警示、Manage action、既有 PDF 可用说明 | `12-archives-access-revoked.svg`。 |
| `12-archives-delete-confirm.png` / `12-archives-delete-failed.png` | FX-17 | 本地数据范围、系统照片不改、Cancel + destructive delete、失败重试 | 两个同名 source。 |

## 出图批次与完成定义

1. **B2：05–06**：先交 05 的 6 张与 06 的 11 张，完成待确认与敏感安全链。
2. **B3：07–08**：交隐藏时期、日期范围和章节编辑的 10 张左右。
3. **B4：09–12**：交预览/PDF/购买/档案的约 25 张；09 只有逐页 6–8 张全部到位才可进入 QA。
4. 每个批次交付时，更新 `reference_manifest.md`：文件真实路径、fixture、`candidate` 状态、source 路径和设计自检结论。
5. 产品确认 PRD 文案/流程后才能标 `approved`；工程和 QA 不能用 candidate 图宣告像素通过。
