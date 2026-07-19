# MemoryBookPage 共享相册架构

## 已完成

- `MemoryBookBuilder` 根据已确认照片和可见章节生成页面序列：封面、献词、目录、章节开场、照片组和结尾页。
- `AlbumPagesPreview` 直接遍历 `MemoryBookDocument.pages`，不再自行拼接固定的 8 页内容。
- `LocalPDFExporter` 使用同一个 `MemoryBookDocument` 逐页创建 PDF，预览和导出不再维护两套章节分页逻辑。
- 最终页面模型再次过滤 `selected + normal` 照片，敏感、排除、隐藏素材不会进入预览或 PDF。
- 页面数量随可见章节变化：`3 + (章节数 × 2) + 1`，不再限制每章最多 3 张照片；单页照片组最多展示 6 张，后续章节继续分页。

## 验证

- `testMemoryBookBuilderUsesEligiblePhotosAndCreatesChapterPages` 通过。
- `testLocalPDFExporterWritesValidPDF` 通过。
- iOS Simulator Debug 构建通过，`git diff --check` 通过。

## 后续验收

- 对 6–8 页预览、A4/Letter PDF 分别渲染截图并做 1× 对比。
- 验证 Warm Paper / Quiet Night / Field Notes 三套样式在预览和 PDF 中一致。
- 增加 PDF 页数、隐藏章节、敏感照片和大相册分页断言。
