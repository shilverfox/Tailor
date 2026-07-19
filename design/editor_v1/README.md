# Tailor · 生命相册页面编辑器 v1 设计交付

**状态：** 设计评审稿（2026-07-15）  
**依据：** `docs/mobile-prd-plans/Tailor_iOS/14_life_album_page_editor_v1_PRD_2026-07-15.md`  
**基准：** iPhone 390 × 844 pt，纵向；编辑页按 A4 / US Letter 比例缩放显示。

## 交付物

| 文件 | 用途 |
| --- | --- |
| `prototype.html` | 可点击、可审查的编辑器流程原型；直接在浏览器打开。 |
| `design_spec.md` | 视觉、页面、状态、交互和开发交付规格。 |
| `screens/editor-key-states.svg` | 关键高保真静态画板：编辑主画布、裁剪、页面管理、阅读预览、导出完成。 |
| `screens/template-system.svg` | 五套 `PageStyle` 模板与安全区/编辑锚点说明。 |

## E01–E09 映射

| PRD | 原型入口 / 状态 | 静态图 / 规格章节 |
| --- | --- | --- |
| E01 相册入口 | `Start / Continue editing` | `design_spec.md` §3.1 |
| E02 编辑器主画布 | `Pages → Edit page`，拖动和缩放图片 | `editor-key-states.svg` artboard 01；§3.2 |
| E03 页面管理器 | `Pages` | artboard 03；§3.3 |
| E04 图片编辑/裁剪 | `Photo → Crop` | artboard 02；§3.4 |
| E05 文本编辑 | `Text` | §3.5 |
| E06 模板/版式 | `Style`、`Layout` | `template-system.svg`；§3.6 |
| E07 自动排版/Book Check | `Layout → Auto arrange`、`••• → Check book` | §3.7 |
| E08 阅读预览/水印/导出准备 | `Preview` | artboard 04；§3.8 |
| E09 导出完成/档案 | `Export PDF` | artboard 05；§3.9 |

## 审查口径

1. 编辑画布不是“PDF 缩略图”。页面是可选中、可操作的真实布局对象。
2. 每个照片/文字元素只保存归一化坐标；预览与 PDF 消费同一份 `MemoryBookDocument`。
3. 图片位置、裁剪、旋转、层级、文字和 `PageStyle` 都必须在预览及导出中一致。
4. 设计不包含虚构宠物行为、情绪或事件；示例文案仅使用用户输入或真实日期。

