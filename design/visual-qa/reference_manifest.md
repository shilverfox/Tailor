# Tailor v1.1 · 像素对照参考清单

版本：v1.1 / 2026-07-15  
配套合同：`ui_scope_contract.md`。  
`approved` 的定义是：产品确认、设计师提供可编辑源、该 PNG 与当前 PRD 一致。当前仓库**没有**满足该定义的 390×844 视觉参考；下表因此不会把旧 PNG 误标为 approved。

## A. 现存文件处置

| 文件/范围 | 尺寸 | 处置 | 原因 | 是否可用于像素叠图 |
| --- | --- | --- | --- | --- |
| `design/screens/01.png` | 390×844 | legacy candidate，待 v1.1 重绘 | 仅旧欢迎主态；无隐私 sheet、无 v1.1 批准源。 | 否 |
| `design/screens/02.png` | 390×844 | deprecated | 只含常规权限页；不含 limited/denied，无法满足 PRD 36。 | 否 |
| `design/screens/03.png` | 390×844 | deprecated | 不含校验、年份关系/错误、其他物种状态。 | 否 |
| `design/screens/04.png` | 390×844 | deprecated | 不含少于三张、失效资源、替换/查看状态。 | 否 |
| `design/screens/05.png` | 390×844 | deprecated | 仅 running；未覆盖 paused/interrupted/low battery/failed/complete。 | 否 |
| `design/screens/06.png` | 390×844 | deprecated | 旧图缺 Sensitive；依赖 swipe/旧三分组，与新版显式待确认要求冲突。 | 否 |
| `design/screens/07.png` | 390×844 | deprecated / conflict | 使用 `The beginning`、`A life remembered` 等推断性标题；无隐藏时期。 | 否 |
| `design/screens/08.png` | 390×844 | deprecated | 无 add/remove/reorder/cover/empty/dirty-exit 状态。 | 否 |
| `design/screens/09.png` | 390×844 | deprecated / conflict | 旧版为封面+短样章，非 6–8 页逐页 `TAILOR · PREVIEW` 水印。 | 否 |
| `design/screens/10.png` | 390×844 | deprecated | 无 purchasing/cancel/failure/restored 与法律细则状态。 | 否 |
| `design/screens/11.png` | 390×844 | deprecated | 仅 completed，缺页尺寸选择、渲染、失败、文件不可用。 | 否 |
| `design/screens/12.png` | 390×844 | deprecated | 缺空态、权限撤回、删除确认/失败。 | 否 |
| `design/prototype.html` | HTML 静态草图 | deprecated as visual reference | 仅 capture-only 脚本，无业务点击；包含与 PRD 冲突的 07/09 内容。 | 否 |
| `design/prototype_v1_1.html` | HTML 四张 06 静态画板 | candidate only for 06 four states | 对齐显式 Needs review / viewer / gate 的方向，但无 actual `PHAsset`、无点击、无 sensitive/never-use 等状态。 | 否，待导出/批准 |
| `design/detailed/v1_1_design_delta.md` | 文档 | authoritative behavior/spec | 对齐新增安全选片和预览规则，但不是像素图。 | 否 |
| `design/detailed/ui_spec.md` | 文档 | authoritative behavior/spec | 提供全部页面文字/状态，不是像素图。 | 否 |

## B. 逐页像素参考注册表

`design reference path` 必须是实际存在的 390×844 PNG 才可从 `blocked` 变更为 `approved`。01–04 第一批已由设计师按本合同重绘并完成尺寸/肉眼检查；其余仍为 `MISSING`，避免工程或 QA 错用旧图。

| 页 | 对照状态 | design reference path | 当前状态 | 阻断原因 |
| --- | --- | --- | --- | --- |
| 01 | welcome-default | `design/reference/v1_1/01-welcome-default.png` | candidate | Fixture `FX-01`: editorial welcome photo only；不是用户宠物/归档素材。 |
| 01 | welcome-privacy-sheet | `design/reference/v1_1/01-welcome-privacy-sheet.png` | candidate | Fixture `FX-01`; no profile/photo data. |
| 02 | privacy-not-determined | `design/reference/v1_1/02-privacy-not-determined.png` | candidate | Fixture `FX-02`: PhotoKit `.notDetermined`. |
| 02 | privacy-limited | `design/reference/v1_1/02-privacy-limited.png` | candidate | Fixture `FX-03`: PhotoKit `.limited`, selected asset count = 12. |
| 02 | privacy-denied | `design/reference/v1_1/02-privacy-denied.png` | candidate | Fixture `FX-04`: PhotoKit `.denied`. |
| 03 | profile-valid | `design/reference/v1_1/03-profile-valid.png` | candidate | Fixture `FX-05`: species dog, name Milo, cameHome 2017, leftUs 2024. |
| 03 | profile-validation-error | `design/reference/v1_1/03-profile-validation-error.png` | candidate | Fixture `FX-06`: blank name, missing leftUs; submit attempted. |
| 03 | profile-unsupported-species | `MISSING: design/reference/v1_1/03-profile-unsupported-species.png` | blocked | 非狗/猫回退态尚未设计。 |
| 04 | references-ready | `design/reference/v1_1/04-references-ready.png` | candidate | Fixture `FX-07`: 3 authorized reference `PHAsset` IDs, all available. |
| 04 | references-under-minimum | `design/reference/v1_1/04-references-under-minimum.png` | candidate | Fixture `FX-08`: 1 authorized reference `PHAsset`, need 2 more. |
| 04 | references-asset-unavailable | `MISSING: design/reference/v1_1/04-references-asset-unavailable.png` | blocked | 被撤销/不可用素材替换态尚未设计。 |
| 05 | running / paused / interrupted / low-battery / failed / complete | `design/reference/v1_1/05-scan-{running,paused,interrupted,low-battery,failed,complete}.png` | candidate | FX-09；独立 SVG 位于 `source/05-scan-*.svg`，扫描缩略图为 `PHAssetMask`。 |
| 06 | high-with-pending / needs-review / viewer / pending-gate | `design/reference/v1_1/06-review-{high-with-pending,needs-review,viewer,pending-gate}.png` | candidate | FX-10；v2 SVG 位于 `source/06-review-*-v2.svg`，主结果口径为 High 2 + Needs review 110 = `We found 112 moments.`；照片区为 `PHAssetMask`。 |
| 06 | sensitive / never-use confirm / manager / excluded / year filter / batch | `design/reference/v1_1/06-review-{sensitive,never-use-confirm,never-use-manager,excluded,year-filter,batch}.png` | candidate | FX-10；v2 SVG 位于 `source/06-review-*-v2.svg`。Sensitive/Excluded 是独立安全分组，不加进 112 主结果口径。 |
| 06 | zero match | `design/reference/v1_1/06-review-zero-match.png` | candidate | FX-11；v2 SVG 以 PRD 例外标题 `No clear matches yet.` 取代计数标题；无生成宠物图。 |
| 07 | visible / edit-periods / hide-confirm / hidden-collapsed / hidden-expanded / range-impact / empty | `design/reference/v1_1/07-timeline-{visible,edit-periods,hide-confirm,hidden-collapsed,hidden-expanded,range-impact,empty}.png` | candidate | FX-12 / FX-13 / FX-14；独立 SVG 位于 `source/07-timeline-*.svg`；hidden 两态无 `PHAssetMask`。 |
| 08 | editor / cover-actions / empty / dirty-exit / save-failed | `design/reference/v1_1/08-chapter-{editor,cover-actions,empty,dirty-exit,save-failed}.png` | candidate | FX-12 / FX-14；独立 SVG 位于 `source/08-chapter-*.svg`，选片区域为 `PHAssetMask`。 |
| 09 | unpurchased pages 1–8 | `design/reference/v1_1/09-preview-unpurchased-page-{1,2,3,4,5,6,7,8}.png` | candidate | FX-16；同名 SVG 位于 `source/`，逐页 `TAILOR · PREVIEW` 水印，照片位为 `PHAssetMask`。 |
| 09 | insufficient / loading / failed / purchased | `design/reference/v1_1/09-preview-{insufficient,loading,failed,purchased}.png` | candidate | FX-15 / FX-16；同名 SVG 位于 `source/`。不足时为说明页；已购态无水印。 |
| 10 | default | `design/reference/v1_1/10-purchase-default.png` | candidate | FX-16；同名 SVG 位于 `source/`。 |
| 10 | purchasing / cancelled / failed / restored | `design/reference/v1_1/10-purchase-{purchasing,cancelled,failed,restored}.png` | candidate | FX-16；同名 SVG 位于 `source/`，取消/失败不丢编辑状态。 |
| 11 | complete | `design/reference/v1_1/11-export-complete.png` | candidate | FX-16；同名 SVG 位于 `source/`，封面是本地 PDF 表现，不是宠物图。 |
| 11 | page-size / rendering / failed / file-unavailable | `design/reference/v1_1/11-export-{page-size,rendering,failed,file-unavailable}.png` | candidate | FX-16；同名 SVG 位于 `source/`。 |
| 12 | populated | `design/reference/v1_1/12-archives-populated.png` | candidate | FX-17；cover 位置为 `PHAssetMask`。 |
| 12 | empty / access-revoked / delete-confirm / delete-failed | `design/reference/v1_1/12-archives-{empty,access-revoked,delete-confirm,delete-failed}.png` | candidate | FX-17；同名 SVG 位于 `source/`。 |

### 第一批设计参考的来源与可编辑源

| 文件 | 可编辑源 | 生成方式 | 设计状态 |
| --- | --- | --- | --- |
| 01–04 candidate PNG | `design/reference/v1_1/source/01-*.svg` 至 `04-*.svg` | SVG 原生矢量排版后本地导出 PNG；01 默认态以既有 welcome editorial asset 为视觉支持 | candidate；产品确认固定英文文案和异常态范围后才可进入 approved。 |

这些 SVG 是新建的 v1.1 参考源，未复用 `design/screens/01.png`–`12.png`。`01-welcome-default.png` 使用的照片只允许作为欢迎页的 editorial visual，任何归档/确认/预览/PDF fixture 均不得使用它。

## C. 必须停止使用的旧图/内容

工程和 QA 不得再以以下内容作验收目标：

1. 任意 `design/screens/01.png`–`12.png` 的色值、字号、间距、CTA 位置或页面结构。
2. `prototype.html` 第 12 行的 `The beginning` / `A life remembered` 章节标题。
3. `prototype.html` 第 14 行的“Cover, contents, and two sample pages”及 `TAILOR · SAMPLE`；新版必须是 6–8 页并逐页原生绘制 `TAILOR · PREVIEW`。
4. `prototype.html` 第 11 行的仅 High/Needs review/Excluded 三分组和 swipe-only 决策叙述。
5. 所有旧图的生成/色块宠物图用于确认、章节、样章和 PDF 位置；这些位置只能使用用户授权的运行时 `PHAsset` 或无照片占位。

## D. QA 使用步骤

1. 先查本 manifest；状态不是 `approved` 即记录“设计基线缺失”，不要判工程视觉失败或通过。
2. 状态 approved 后，取得对应 reference PNG、同数据夹具的 runtime PNG 和叠图。
3. 截图路径写入 `01-12_acceptance_matrix.md` 的对应条目，并注明版本、设备、数据夹具与对比结论。
4. 如果 PRD 或设计规则变更，立即将受影响 reference 降回 `deprecated`，重新出图后才能继续叠图。
