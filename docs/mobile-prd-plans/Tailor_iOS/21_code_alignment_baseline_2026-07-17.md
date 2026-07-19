# Tailor iOS · 代码整体对齐基线

**日期：** 2026-07-17  
**范围：** iOS 当前工作区；以 `Tailor_v1_PRD.md`、`14_life_album_page_editor_v1_PRD_2026-07-15.md`、`19_p0_2_remaining_crop_text_render_save_plan_2026-07-16.md` 为产品/技术依据。  
**方法：** 静态代码、模型、服务、UI 测试与已归档的局部回归结果交叉核对；本文件不是发布验收，也不替代真机与 PDF 像素验证。

## 1. 对齐结论

当前工程已经具备统一的 `MemoryBookDocument → MemoryBookPage → MemoryBookElement` 主模型、五套样式 token、基本的 Editor / Reader / PDF 路径、文字共享排版合同，以及 PhotoKit/Vision 的端侧扫描路径。

但它仍处于 **“P0-2 的局部实现可运行，整体产品契约未收口”** 状态。下一阶段不得按界面逐块堆功能，而要按以下顺序收敛：

```text
P0-A Crop 数据与事务闭环
    ↓
P0-B Text 编辑、Book Check 与导出阻断闭环
    ↓
P0-C 文档持久化、导出冻结与 Preview/PDF manifest 闭环
    ↓
G-EDITOR-03 / 04 / 05 真机、视觉、资产与支付门禁
```

在 P0-C 关闭前，不启动 P0-3 的页面管理扩展，也不把当前 PDF 表述为“与预览一比一”。

## 2. 已对齐的事实

| 领域 | 已有实现 | 代码依据 | 结论 |
| --- | --- | --- | --- |
| 页面数据源 | 编辑器使用 `MemoryBookDocument`、`MemoryBookPage`、`MemoryBookElement`；`ArchiveDocument` 保存 `memoryBook`。 | `ArchiveModels.swift`：`MemoryBookDocument`、`ArchiveDocument.memoryBook`；`SwiftDataArchiveRepository.swift` 解码/保存 `memoryBookData`。 | 主数据模型已具备。 |
| 文字排版基础 | `MemoryBookTextLayoutSpec`、measurement、Preview/PDF attributed-text adapter 已存在；UIKit 桥接已修复无约束尺寸时文字离屏的问题。 | `ArchiveModels.swift`：text layout/adapter；`AlbumFeatureViews.swift`：`MemoryBookAttributedTextPreview.sizeThatFits`。 | B1 已有基础；仍需 B2/B3 签收。 |
| 图片裁剪基础 | `FillCropConstraint`、`MemoryBookCropSession`、Preview/PDF 共用变换几何已存在。 | `ArchiveModels.swift`；`AlbumFeatureViews.swift`：`CropEditorSheet`；`ProductionServices.swift`：`draw(image:...)`。 | A 组已有大量代码与测试基础。 |
| 样式/页面渲染 | 五套模板都进入 `MemoryBookPageStyle` / render plan，PDF 显式绘制背景、水印、胶片边框。 | `ArchiveModels.swift`：`MemoryBookPageRenderPlan`；`ProductionServices.swift:89-154`。 | 同源方向正确，但未完成像素门禁。 |
| 本地扫描 | PhotoKit + Vision 物种门 + feature-print 距离 + 本地文件索引 + 平均哈希去重已实现。 | `PhotoKitVisionScanner.swift:24-103,197-230`。 | 具备候选发现能力，不等于“特定宠物识别准确率已达标”。 |
| 草稿保存 | `MemoryBookDocument` 编解码进 SwiftData 档案。 | `SwiftDataArchiveRepository.swift:64-67`。 | 有保存通道，尚未证明所有编辑/导出状态的冷启动一致性。 |

## 3. 代码—PRD 偏差矩阵

### P0：必须先收口

| ID | PRD 要求 | 当前代码事实 | 对齐动作 | 验收 |
| --- | --- | --- | --- | --- |
| CA-01 | Book Check 的 `Go` 要定位到具体问题文字并打开编辑字段。 | `MemoryBookIssue` 只有 `pageID` 与 `message`；`BookCheckSheet` 只调用 `selectPage(pageID)`。 | 增加 `elementID`/`field`，将焦点、Text sheet 与无障碍提示作为同一跳转契约。 | B3：溢出文本 `Go` 后对应字段聚焦。 |
| CA-02 | 被 blocker 阻断时导出不得产生任何新 PDF。 | Editor 菜单会先 `checkBook()`，但 `LocalPDFExporter` 自身只验证资产存在性，不验证 text/empty-frame blocker。 | 在 exporter 边界强制 preflight；使用临时目录测试文件清单/哈希。 | B3：阻断导出前后目录相同。 |
| CA-03 | 本次导出冻结，导出过程中修改只影响下次导出。 | `renderManifest` 在 `export` 进入时生成，但没有可追溯的 document hash、导出记录或测试注入的冻结合同。 | 抽出 `ExportSnapshot` / `MemoryBookRenderManifest` 持久化记录；渲染只读 snapshot。 | C：两次导出 hash/内容分别对应开始时状态。 |
| CA-04 | 最近导出的 PDF 可在下次进入档案访问，且不覆盖历史版本。 | 文件名已使用时间戳+UUID；但 `MemoryBookDocument` 没有 `lastExportedAt` / `ExportRecord`，档案仅依赖目录扫描/运行态 URL。 | 建立 `ExportRecord` 并与档案原子保存；失败/取消不得写入。 | C：重启后可显示最近文件，历史文件仍可访问。 |
| CA-05 | 所有图片选择/预览/PDF 都统一执行可入册资产规则，缺失资产显示占位并阻断。 | PDF 直接抛 `photoUnavailable`；没有证明编辑器/Reader 的缺失资产占位和统一 eligibility selector。 | 提取共享 `ArchiveAssetEligibility`，四个入口统一消费，并增加缺失状态 UI。 | AST-001/002。 |
| CA-06 | 照片确认页在底部仍可稳定上滑，不能抖动/锁死。 | `ArchiveFeatureViews.swift` 有针对回调/scroll oscillation 的局部注释，但没有该场景的稳定 UI 回归证据。 | 先复现后将确认页滚动状态与扫描/缩略图更新解耦；新增真机/UITest 回归。 | 用户所报“到底后无法上滑”复测通过。 |

### P1：与核心编辑器相关，但不应插队 P0-C

| ID | PRD 要求 | 当前偏差 | 对齐动作 |
| --- | --- | --- | --- |
| CA-07 | 页面管理：受限重排、新增、删除二次确认、复制、长页面稳定滚动。 | 存在 `PageManagerSheet` 入口与局部操作，但没有完整 ED-005…008 证据。 | P0-C 后建立专门的 page mutation 测试组。 |
| CA-08 | 图片编辑：吸附线、边界缩放、1° 旋转/长按复位、重设确认。 | Crop / 层级 / Replace / Remove 存在局部实现；完整交互与所有约束的验收不完整。 | 归入 P0-A 的剩余补齐，不另开散点任务。 |
| CA-09 | 五模板 × A4/Letter 的 Preview/PDF 一比一。 | 两端均读取 render plan，但没有 10 组合 PDF raster/热图证据。 | C 完成后执行 G-EDITOR-03，不以代码审阅替代。 |
| CA-10 | Scan 对“特定宠物”准确、可增量、重复图降权。 | 当前索引是每档案 JSON + `VNFeaturePrintObservation` 归档；固定阈值 `animalGate=0.52`、`similarityGate=0.42` 未有真实标注集校准；没有 `PHPhotoLibraryChangeObserver`/后台增量任务。 | 另立识别质量工作流：标注集、precision/recall、错误桶、阈值配置；SQLite/Accelerate 仅在测量证明确有性能瓶颈后采用。 |
| CA-11 | Release 不得含购买绕过。 | Debug/UI 测试绕过路径用于开发与回归；尚无 Release archive 审计证据。 | 用编译条件隔离、CI 静态检查和 Archive 验证。 |

## 4. 架构约束（即日起作为代码门禁）

1. **唯一编辑数据源：** 新 UI 或 exporter 不得从 `profile + chapters + photos` 临时重建已编辑相册。`LocalPDFExporter.export(profile:photos:chapters:...)` 只作为旧兼容入口，产品路径必须传入已保存的 `MemoryBookDocument`。
2. **同源渲染：** Preview、Editor、Book Check、PDF 必须只读取 `MemoryBookPageRenderPlan` / `MemoryBookTextLayoutSnapshot`。不新增第二套 frame、字体、裁剪或排序算法。
3. **操作事务：** 每个 Done / Fit / crop / layout / page mutation 只提交一次 document transaction；只有提交后才 `persist()`。
4. **导出冻结：** Export 接收 immutable snapshot，而不是对 `@Binding MemoryBookDocument` 或正在编辑的 book 进行二次读取。
5. **安全资产边界：** `selected && normal && !neverUse && !hidden` 的规则不能散落在 View/PDF/Picker；缺失资产是显式状态，不能静默跳过。
6. **测试不是按钮存在断言：** 每个 P0 UI 操作至少具备状态断言、稳定 accessibility identifier、截图/结果包；渲染改动还必须有 manifest 或 raster 证据。

## 5. 冻结后的执行顺序

1. **修复 CA-06**：先处理用户已报的确认页到底无法回滑；不与编辑器新功能并行混改。
2. **完成 P0-A**：Crop 事务和 image transform 的残余缺口，关闭后做独立 QA/设计验收。
3. **完成 P0-B**：文字编辑器的剩余字段/状态/Book Check 定位，含 CA-01/02。
4. **完成 P0-C**：持久化、导出冻结、导出记录、manifest、CA-03/04/05。
5. **运行 G-EDITOR-03/04/05**：5 模板×2 纸张，真机资产/离线/权限，StoreKit Release 审计。
6. **最后进入 P0-3**：页面管理与阅读器增强。

## 6. 本轮静态审计边界

- 已验证的局部文字修复：画布标题/caption 可见；安全拖拽与两次 Undo 回归通过（`/tmp/tailor-text-safe-drag-r8.xcresult`，1/1）。
- 本轮未重跑完整测试套件、未执行真机 PDF 栅格比对，也未对识别准确率作任何发布级结论。
- 工作区当前存在大量未提交的产品、设计、代码与测试变更；在 P0-C 闭环前不得把它们合并为“功能完成”的单一提交。后续应按 P0-A / P0-B / P0-C 分批提交，确保可回退。

## 7. 2026-07-17 代码补齐结果

本轮已完成并通过局部自动化验证：

| 项 | 已落地的代码契约 | 证据 |
| --- | --- | --- |
| CA-06 | 确认页照片格与底部 CTA 处于同一滚动上下文；首张照片、网格、CTA 均有稳定测试标识。 | UITest 到底后可回到首图。 |
| CA-01 | `MemoryBookIssue` 记录 `pageID + elementID + field`；Book Check 从当前 binding 重算；弹层关闭后以不可变目标打开对应字段。 | `testBookCheckGoOpensTheBlockingTextField`。 |
| CA-02 | `LocalPDFExporter` 在创建任何文件前执行 Book Check preflight。 | `testBookCheckTextIssueTargetsItsFieldAndExporterCreatesNoPDFWhenBlocked`。 |
| CA-03 | `MemoryBookExportSnapshot` 冻结迁移后的 document 与 render manifest，并附 SHA-256 指纹。 | `testExportSnapshotFreezesRenderManifestUntilTheNextExport`。 |
| CA-04 | `ArchiveDocument.exportRecords` 仅存文件名与导出元数据；冷启动优先使用最近可用的非水印记录。 | `testArchiveExportRecordsRoundTripWithoutPersistingSandboxPaths`。 |

汇总回归结果包：`/tmp/tailor-code-alignment-r1`，7 项通过（5 项模型/服务、2 项 UI）。

仍未关闭：CA-05 的共享资产 eligibility/missing-asset UI，P0-A 图像编辑余项，5 模板 × 2 纸张的 Preview/PDF 栅格比对，以及真机/Release 审计。它们不能因本轮通过而视为完成。
