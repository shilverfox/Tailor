# Tailor 页面编辑器与一比一导出

## 目标

预览页就是最终相册页。用户在 SwiftUI 页面画布中编辑图片位置、大小和裁剪后，PDF 直接使用同一份 `MemoryBookDocument.pages[].elements` 渲染，不再维护第二套版式规则。

## 模型

- `MemoryBookPage`：页面类型、标题、章节、分页和元素集合。
- `MemoryBookElement`：图片或文字、归一化坐标、裁剪缩放、裁剪偏移、旋转角度和层级。
- 坐标范围为 0...1，适配 Letter、A4 和不同 iPhone 预览尺寸。
- 页面旧数据没有 `elements` 时自动解码为空数组，继续兼容已有草稿。

## 编辑交互

- 点击图片选中并显示陶土橙边框。
- 拖动图片修改归一化位置。
- 双指捏合修改裁剪缩放。
- 章节照片不再截断为 6 张，超过 6 张自动分页。
- 仅允许 `isEligibleForArchive` 的照片进入画布和导出。

## 导出规则

- `LocalPDFExporter.export(document:)` 优先读取编辑后的页面模型。
- PDF 页面显式绘制背景和纸张表面，避免透明页在部分阅读器中显示为黑色。
- 封面、章节开场页、照片页使用相同的元素坐标语义。
- 旧的 `export(profile:photos:chapters:pageSize:)` 保留为兼容入口。

## 验收

1. 在预览中拖动图片后重新导出，PDF 中图片位置发生相同变化。
2. 捏合图片后，预览与 PDF 的裁剪比例一致。
3. 章节超过 6 张时，所有已选照片均出现在后续页面。
4. Warm Paper、Quiet Night、Field Notes、Cinema、Film Album 均显式填充背景。
5. 旧草稿可正常打开，未保存编辑不影响系统照片。
