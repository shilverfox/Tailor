# P0-2 / A 组 Crop 产品与设计最终独立复验

- 复验日期：2026-07-16
- 复验范围：`19_p0_2_remaining_crop_text_render_save_plan_2026-07-16.md` §A，及 `18_p0_2_editing_interactions_qa_acceptance_2026-07-16.md` §3（CRP-001…007）。
- 复验方法：独立读取当前生产源码、读取 xcresult 汇总及**逐张审阅真实 Simulator fixture 截图**；不以研发结论、按钮存在或 render-plan 字段相等替代产品/设计验收。
- 结论：**不通过（A 组不得签收；不得进入 B 组 Text）。**

## 可确认的正向证据

| 项目 | 独立结论 | 证据 |
| --- | --- | --- |
| 数据约束与事务基础 | 通过 | `FillCropConstraint` 已考虑旋转，`MemoryBookCropSession` 将草稿与 document 分离（`Tailor/Domain/ArchiveModels.swift:349-422,489-548`）。模型结果 `/tmp/tailor-crop-tests/Logs/Test/Test-Tailor-2026.07.16_15-39-19-+0800.xcresult`：47/47 通过。 |
| Crop 退出/Reset 基础路径 | 部分通过 | Crop sheet 有明确 Cancel/Done、dirty 退出三选项、Reset 二次确认及交互关闭保护（`Tailor/Features/AlbumFeatureViews.swift:675-792`）。UI 交互用例 `/tmp/tailor-crop-ui-final9/Logs/Test/Test-Tailor-2026.07.16_15-57-26-+0800.xcresult`：1/1 通过。 |
| Replace 数据路径 | 部分通过 | `replacePhoto` 保留 frame/rotation/z-index 并按新比例计算 fill crop（`Tailor/Domain/ArchiveModels.swift:1032-1058`）；独立 UI 结果 `/tmp/tailor-crop-replace/Logs/Test/Test-Tailor-2026.07.16_16-02-43-+0800.xcresult`：1/1 通过。 |
| 固定夹具并非缺图占位 | 通过 | `PhotoAssetThumbnail.localCropFixture` 生成横、竖、方形中心/边缘标记（`Tailor/Features/TailorComponents.swift:96-135`）；四张附件的 manifest 与截图均可读取。 |
| 代码卫生 | 通过 | 本次复验执行 `git diff --check` 无输出。 |

## 阻断项

### CRP-DESIGN-001：四张 Crop stage 截图均未达到可签收的“固定原元素框 + 72% 外围遮罩”视觉状态

复验逐张打开了以下自动化附件（非占位图）：

- `/tmp/tailor-crop-fixture-screenshots-v2/51667154-18DB-42C1-8C7B-CDDCF4EBBF45.png`（landscape）
- `/tmp/tailor-crop-fixture-screenshots-v2/0CFCB140-B9AB-47B5-BA05-B2DA14BCCB37.png`（portrait +15°）
- `/tmp/tailor-crop-fixture-screenshots-v2/F5C10D36-7118-4A1E-9CA3-C298CFAFB1BC.png`（portrait -15°）
- `/tmp/tailor-crop-fixture-screenshots-v2/4A94C34D-71F0-475A-8AE6-FEB5AC35ABF0.png`（square +15°）

这些截图确实是来自实际全屏 Crop 页（fixture UI 结果 1/1 通过，manifest：`/tmp/tailor-crop-fixture-screenshots-v2/manifest.json`），但视觉结果不合格：横图的固定框明显被推进到屏幕右侧并截断；三张旋转图中，固定框尺寸/位置失衡，内容覆盖到辅助说明与底部操作区附近。用户无法把橙色边框稳定理解为当前原元素容器，也无法可靠判断 Done 后的版面焦点。

这违反 CRP-001 的“元素框固定”和 CRP-002 的“无背景空白且可理解地看到编辑区域”。72% 的 `Color.black.opacity(0.72)` 声明存在（`AlbumFeatureViews.swift:681-687`），但截图显示的固定窗/遮罩/操作区关系仍不成立，故不能以实现行或 accessibility ID 作为视觉通过证据。

### CRP-DESIGN-002：Crop stage 没有使用编辑器/导出同一套**绝对容器定位**

编辑器图片使用 `MemoryBookImageTransform(...).position(x: frame.midX, y: frame.midY)`（`Tailor/Features/AlbumFeatureViews.swift:282-295`）。Crop stage 虽创建同一 `MemoryBookImageTransformGeometry`（`AlbumFeatureViews.swift:689-701`），却没有将 transform view 或手势层 `.position` 到 `cropFrame` 的 `midX/midY`；它们只设置宽高。相反，固定描边使用的是 `frame(width: frame.width, height: frame.height)`。

这正是上述截图中“内容/手势框/固定边框视觉不同步”的生产代码原因。它意味着所谓共享 helper 仍只共享了部分数学字段，而非一个可复用的完整几何呈现契约；不能证明 Crop、编辑器和 PDF 的最终焦点一致。

### CRP-DESIGN-003：CRP-003/004 的 UI 测试没有验证用户看到的结果

`testCropDraftCancelDoneUndoRedoAndResetConfirmation` 做了真实 pinch/drag、Cancel、Reset、Done、Undo/Redo（`TailorUITests/TailorOnboardingUITests.swift:327-373`），这是有效进展；但它只断言控件存在/路径可走，三张截图未以元素位置、图片标记或 document 回读断言证明：

1. Cancel 后焦点、frame、crop、rotation、lock 均恢复；
2. Done 后 Undo 恢复进入前，Redo 恢复提交后；
3. Reset→Done→Undo 恢复 crop/frame/rotation/z-index。

模型层的快照测试可作为事务基础，但不能补替真实页面中焦点一比一一致性的视觉签收；尤其在 CRP-DESIGN-002 已证明 stage 定位错误时。

### CRP-DESIGN-004：退出源覆盖仍没有“切页”交互证据

`interactiveDismissDisabled`、scene phase 恢复确认与顶部 Cancel 均实现（`AlbumFeatureViews.swift:747-760`），但全屏 Crop sheet 没有“切页”入口，测试也没有验证页面切换时的统一状态机。这不能签收 CRP-006 要求的“返回编辑器 / 切页 / 应用退后台”三类退出源。scene phase 仅靠 onChange 条件分支，当前没有独立自动化回读。

## 矩阵判定

| 用例 | 判定 | 说明 |
| --- | --- | --- |
| CRP-001 | **不通过** | 页面和按钮存在；真实截图中固定元素框的位置/尺寸不可签收。 |
| CRP-002 | **不通过** | 47 项模型约束可采信；横/竖/旋转实际视觉截图暴露固定框与内容不同步，不能证明无空白/焦点正确。 |
| CRP-003 | 部分通过，未签收 | 本地草稿模型通过；UI 没有 Cancel 前后图像/几何回读。 |
| CRP-004 | 部分通过，未签收 | Done/Undo/Redo 路径通过；未验证三态的可见结果。 |
| CRP-005 | 部分通过，未签收 | Reset 确认存在；缺 Reset→Done→Undo 的完整可见/数据回读证据。 |
| CRP-006 | 部分通过，未签收 | 顶部 Cancel 和 scenePhase 代码存在；切页与退后台状态机没有独立交互证据。 |
| CRP-007 | 部分通过，未签收 | Replace 数据测试通过；尚无替换后进入 Crop 的真实截图证明新 source 在 Stage/Editor/PDF 同一焦点。 |
| Preview / A4 / Letter / PDF | 不通过（本组不可关闭） | render-plan 字段相同不等于实际渲染一致；P0-2 组 C 及最终 PDF raster 仍待执行。 |

## 最小 P0 返工要求

1. 将 Crop stage 的 image transform、透明手势面和固定框使用**同一个 container CGRect**：全部明确定位到 `cropFrame.midX/midY`，并确保 transform 的 clip → scale/offset/rotation → source 顺序与 Editor/PDF 保持一致。
2. 重新产出 landscape、portrait、±15°、square 的全屏截图；每张必须可见完整橙色固定框、72% 框外遮罩、图片内容、说明和底部操作区，三者不得互相覆盖或被截断。
3. 为 Cancel / Done→Undo→Redo / Reset→Done→Undo 添加可审阅的前后 marker 或 document snapshot 断言，并保留真实手势路径。
4. 为 page switch 与 background/foreground 各补一条独立状态机/UI 证据；若全屏 Crop 不允许切页，需通过交互关闭禁用与产品文案明确该约束，而不是把该退出源遗漏。
5. Replace 后进入 Crop，归档新 source 的 Crop stage 截图；组 C 再补 Preview、A4、Letter 的相同焦点渲染证据。

## 保留的最终门禁（不属于本次签收）

- G-EDITOR-03 真实设备、真实 Photos 资产的裁剪/滚动/导出：**Not run**。
- 5 个模板 × A4 / US Letter PDF 栅格化、heatmap：**Not run**。
- P0-1 最终视觉发布门禁：**仍待关闭**。

## 最终结论

**P0-2 A 组 Crop：不通过。** 研发需先解决 CRP-DESIGN-001/002 的实际可见几何问题，并补齐上述最低验收证据。产品/设计复验和 QA 复测通过前，不得启动 B 组 Text。
