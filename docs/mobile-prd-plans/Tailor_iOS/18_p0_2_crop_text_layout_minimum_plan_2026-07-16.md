# P0-2 最小实施计划：裁剪、文本溢出与明确版式

> 范围：只实现编辑器 E04/E05/E06 的三项阻断能力，不改 PageStyle/PDF、页面管理、购买、自动排版或真实资产管线。

## 目标与边界

1. **独立裁剪模式**：从 `Photo → Crop` 进入全屏裁剪态；照片容器框固定，单指移动内容、双指缩放，始终以 Fill 显示而不露空白；`Reset` 恢复进入裁剪前的默认值，`Cancel` 原样回滚，`Done` 作为一次可撤销提交。
2. **文本真实溢出**：按元素可用 frame 与共享字号规则测量文本。超出时在 Text 面板显示阻断提示和 `Fit text`；Fit text 仅缩小该元素的字号档/容器高度至可容纳，且可撤销。Book Check 使用同一测量结果。
3. **明确版式与超量摘要**：Layout 面板显式提供 `Single`、`Two-up`、`Grid 2×2`、`Grid 3×2`、`Note`。切换前计算当前页超出照片数，显示“保留/移至同章节新页”的摘要；确认后一次性更新本页和新增页，取消不写入。

## 文件与最小数据契约

- `Tailor/Domain/ArchiveModels.swift`：增加布局容量/布局迁移规划的纯模型 API；增加文本量测/溢出 API，供 UI、Book Check 共同使用。
- `Tailor/Features/AlbumFeatureViews.swift`：裁剪全屏 sheet、Text 溢出与 Fit text UI、Layout 明确卡片和确认摘要。
- `TailorTests/TailorFeatureTests.swift`：裁剪 Cancel/Done/Reset、文本 overflow/Fit text、五种布局及 overflow 移页的纯模型测试。
- `TailorUITests/…`：只增加可发现的 Crop / Fit text / 五种布局入口断言；真实 Photos 手势由后续真机门禁覆盖。

## 验收

- Crop 的 Cancel 不改变 `cropScale/cropOffset`，Done 改变且 undo 可恢复，缩放范围 `[1, 3]`、offset 被约束为 Fill。
- overflow 被模型识别并由 `checkBook()` 作为 blocking issue；Fit text 后该 issue 消失或明确提示不可容纳。
- 每个 Layout 选项有实际容量；超量迁页确认前 document 不变，确认后图片不丢失、不重复、页码连续、单一 undo 可回退。

## 非目标/风险

- 不承诺此项完成 PDF raster 或真机视觉门禁。
- 文本采用可确定的本地近似测量，SwiftUI/PDF 的逐像素行盒一致性属于 P0-1 视觉验收后续项。
