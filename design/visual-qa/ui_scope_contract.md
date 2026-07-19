# Tailor v1.1 · 像素级还原 UI 范围合同

版本：v1.1 / 2026-07-15  
适用对象：产品、设计、iOS 工程、QA。  
目的：为逐页叠图建立唯一、可审计的设计输入；避免把旧概念图或文字规格误当成像素级参考。

## 1. 权威顺序与使用规则

1. `docs/mobile-prd-plans/Tailor_iOS/Tailor_v1_PRD.md` 是行为、隐私和内容安全的最高约束。
2. `design/detailed/v1_1_design_delta.md` 与 `design/detailed/ui_spec.md` 是组件/状态规则来源，不能单独作为像素参考。
3. **只有本合同的 `reference_manifest.md` 标记为 `approved` 的 390×844 PNG，才可以用于 iOS 截图 1:1 叠图。**
4. `design/screens/01.png`–`12.png` 和 `design/prototype.html` 是 v1.0 概念资料；除非 manifest 明确逐状态批准，均不得作为视觉验收基线。
5. `design/prototype_v1_1.html` 仅是 06 的静态交互说明，不是可点击原型，也不是全流程视觉基线。

不符合以上规则的实现，最多可被记录为“功能可运行”，不得标记为“像素级通过”。

## 2. 统一捕获合同

| 项目 | 合同 |
| --- | --- |
| 设备与方向 | iPhone portrait，390×844 pt，1× PNG；不含外部设备边框、浏览器或桌面背景。 |
| 系统状态 | 记录 iOS/设备型号/语言/动态字体；状态栏差异可裁至 app safe-area 后比对，但必须在报告注明。 |
| 数据夹具 | `Milo` 仅作演示名；以受控 `PHAsset` fixture 映射真实本地照片。禁止用生成宠物图替代确认、章节、样章或 PDF 图。 |
| 可比区域 | 固定 chrome、字体、颜色、间距、组件尺寸、CTA、卡片、错误/空态；照片内容只比裁切框、圆角、遮罩和状态徽章，不比像素主体。 |
| 对比方法 | 同尺寸叠图 50% opacity；固定 chrome 最大 2 pt、动态照片裁切最大 4 pt；不得替换设计 token。 |
| 每张证据命名 | `design/reference/v1_1/<page>-<state>.png` 与 `artifacts/visual-qa/<build>/<page>-<state>-runtime.png`。 |
| 状态通过定义 | 有 approved 设计 PNG、运行时截图、叠图、差异清单、产品/设计/QA 关闭记录。缺一项即 blocked。 |

## 3. 本轮逐页范围与必备状态

下面的 `required reference path` 是设计师必须交付的目标路径；文件不存在时状态即为 `blocked`，不是“待以后优化”。

| 页 | 状态 ID | PRD 必须覆盖 | required reference path | 当前门禁 |
| --- | --- | --- | --- | --- |
| 01 | `welcome-default` | 欢迎、创建、隐私入口、无价格 | `design/reference/v1_1/01-welcome-default.png` | blocked：无 approved v1.1 PNG |
| 01 | `welcome-privacy-sheet` | 隐私说明返回路径 | `design/reference/v1_1/01-welcome-privacy-sheet.png` | blocked |
| 02 | `privacy-not-determined` | 三项承诺、完整授权前置说明、手动选择 | `design/reference/v1_1/02-privacy-not-determined.png` | blocked |
| 02 | `privacy-limited` / `privacy-denied` | 受限管理/继续；拒绝后的手动选择/Settings | `design/reference/v1_1/02-privacy-limited.png`; `02-privacy-denied.png` | blocked P0 |
| 03 | `profile-valid` / `profile-validation-error` / `profile-unsupported-species` | 狗猫、必填、年份关系、其他物种提示 | `03-profile-valid.png`; `03-profile-validation-error.png`; `03-profile-unsupported-species.png` | blocked |
| 04 | `references-under-minimum` / `references-ready` / `references-asset-unavailable` | 3–5、禁用/可启动、失效素材替换 | `04-references-under-minimum.png`; `04-references-ready.png`; `04-references-asset-unavailable.png` | blocked |
| 05 | `scan-running` / `scan-paused` / `scan-interrupted` / `scan-low-battery` / `scan-failed` / `scan-complete` | 显式开始、暂停/恢复、仅用户返回后恢复、失败保留 | `05-scan-*.png` | blocked P0 |
| 06 | `review-high-with-pending` / `review-needs-review` / `review-viewer` / `review-pending-gate` | 可发现待确认、点按决策、创建时间线拦截 | `06-review-high-with-pending.png`; `06-review-needs-review.png`; `06-review-viewer.png`; `06-review-pending-gate.png` | static candidate only，非 approved |
| 06 | `review-sensitive` / `review-never-use-confirm` / `review-never-use-manager` / `review-excluded` / `review-year-filter` / `review-zero-match` / `review-batch` | 敏感、永不使用、恢复、筛选、零匹配、批量 | `06-review-sensitive.png`; `06-review-never-use-confirm.png`; `06-review-never-use-manager.png`; `06-review-excluded.png`; `06-review-year-filter.png`; `06-review-zero-match.png`; `06-review-batch.png` | blocked P0 |
| 07 | `timeline-visible` / `timeline-edit-periods` / `timeline-hide-confirm` / `timeline-hidden-collapsed` / `timeline-hidden-expanded` / `timeline-empty` | 章节、年份/日期隐藏、无缩略图隐藏态、恢复、空态 | `07-timeline-*.png` | blocked P0 |
| 08 | `chapter-editor` / `chapter-empty` / `chapter-dirty-exit` / `chapter-save-failed` | 标题、note、封面、排序、空章、离开/失败保留 | `08-chapter-*.png` | blocked |
| 09 | `preview-unpurchased-page-1` … `page-8` / `preview-insufficient` / `preview-loading` / `preview-failed` / `preview-purchased` | 6–8 页、逐页水印、分页、素材不足、重试、无水印 | `09-preview-*.png` | blocked P0 |
| 10 | `purchase-default` / `purchase-purchasing` / `purchase-cancelled` / `purchase-failed` / `purchase-restored` | 一次性价格、法律文案、恢复、失败保留 | `10-purchase-*.png` | blocked |
| 11 | `export-page-size` / `export-rendering` / `export-complete` / `export-failed` / `export-file-unavailable` | A4/Letter、进度、本地分享、重试 | `11-export-*.png` | blocked P0 |
| 12 | `archives-populated` / `archives-empty` / `archives-access-revoked` / `archives-delete-confirm` / `archives-delete-failed` | 多档案、权限、删除二次确认与失败 | `12-archives-*.png` | blocked |

## 4. 跨页安全验收链

以下不是单页局部视觉项，必须使用同一 fixture 连续捕获并在 QA 报告中列出 asset ID：

| 链路 | 必备截图 | 通过条件 |
| --- | --- | --- |
| Sensitive → Never use | 06 sensitive、06 confirm、07 timeline、08 chapter、09 preview、11 PDF 预览/导出 | 被标记 asset 只在 Never use 管理器按规则出现；不出现在章节封面、样章或 PDF；系统 Photos 原图未被操作。 |
| Hide date range | 07 hide range、07 collapsed hidden、09 preview、11 PDF | 隐藏时期在折叠前无代表图；其任何照片/封面不进入预览或 PDF。 |
| Pending choices | 06 High、06 Needs review、06 viewer、06 pending gate、07 timeline | 从 High 两次可达到明确选择；未确认候选不会静默进入时间线。 |
| Preview parity | 07 visible timeline、09 pages 1–8、11 complete PDF | 仅当前合格 selected 素材，模板/标题/note/页尺寸切换后重新渲染；未购买每页水印、已购无水印。 |
| Non-coercive resume | 05 paused/interrupted、12 archive resume、app relaunch | 只能由用户打开档案后恢复；不存在通知、自动旧照、倒计时或施压文案。 |

## 5. 关闭规则

- 设计师只可将状态由 `blocked` 改为 `candidate`：提交设计 PNG、可编辑源链接及状态说明。
- 产品确认 PRD 文案/行为后，才可改为 `approved`。
- 工程提交对应 runtime 截图和实现 commit 后，QA 才可改为 `verified`。
- 任何旧图或与 PRD 冲突的图不得通过“微调代码”继续使用；先替换 reference，再做叠图。
