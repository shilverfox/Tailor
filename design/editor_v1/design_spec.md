# Tailor 生命相册页面编辑器 v1 · 视觉与交互规格

## 1. 设计原则

编辑器应让用户“安排一本书”，不是操作复杂的专业排版软件。默认自动成册足够好；需要表达时，用户可以轻量地拖动、裁剪、编辑真实照片与自己的文字。编辑器的工作区安静克制，阅读预览才让页面成为主角。

### 1.1 基础 token

| Token | 值 | 用途 |
| --- | --- | --- |
| `paper` | `#F8F3E8` | Warm Paper 默认页面背景 |
| `ink` | `#163D33` | 主文字、主按钮、Quiet Night 背景 |
| `clay` | `#BD5A3C` | 选中态、重点、控制柄 |
| `sage` | `#DCE4D0` | 信息块、Field Notes 背景 |
| `line` | `#DDD5C5` | 边框、辅助线 |
| `workspace` | `#193B34` 92% | 编辑页外部工作区 |
| `danger` | `#A84337` | 仅破坏性操作和阻断错误 |

- 标题：`New York` / `Iowan Old Style`，42/48 pt（页面内按样式 token 映射）。
- UI：SF Pro Rounded / SF Pro，17 pt；辅助信息 13 pt。
- 触控目标不小于 44 × 44 pt；编辑器底部工具项最小 56 pt 高。
- 画布安全区：页面四边 7%；标题区与页码区为模板保护层，用户元素不能拖入。

## 2. 页面系统与可编辑对象

页面始终按纸张比例置中，工作区不随页面滚动；下方缩略条/面板在需要时覆盖工作区，而不覆盖页面的关键内容。

| 对象 | 可见反馈 | 可操作内容 |
| --- | --- | --- |
| 照片元素 | 陶土橙 2 pt 框、4 个圆角控制点、底部拖动柄 | 拖动、捏合、裁剪、替换、删除、旋转、层级 |
| 文本元素 | 仅选中时显示虚线框 | 编辑、三档字号、安全区内移动、对齐 |
| 模板背景/页码/水印 | 无选中反馈 | 不可编辑 |
| 页面缩略图 | 当前页深绿描边，已修改页右上角陶土点 | 跳转；受限页面可长按拖动重排 |

选择层不改变成品页面；在阅读预览和 PDF 中绝不绘制选框、控制点、辅助线或工作区。

## 3. E01–E09 页面规格

### 3.1 E01 · 相册入口

- 从 Timeline 底部进入；新文档主按钮 `Edit album`，已有草稿为 `Continue editing`。
- 卡片显示模板、页数、最后编辑时间与 `Draft saved` 状态。无有效照片显示 `Choose photos to begin`，转照片确认。
- 入口预览仅是一张封面卡，不代表最终 PDF；点击后才进入 E02。

### 3.2 E02 · 编辑器主画布

顶栏：返回、`4 of 18`、Undo、Redo、More。主画布位于深绿工作区中央，页面始终有明确纸张边缘与阴影。底栏固定五个入口：`Pages / Layout / Photo / Text / Style`。

- 无选择：显示页面级工具（新增/复制页、版式、全册风格、检查）。
- 选择图片：`Photo` 变为选中状态；面板为 Replace、Crop、Rotate、Layer、Remove。
- 单指拖动：出现水平/垂直中心线、页边安全线、相邻元素对齐线；松手后写入一个撤销事务。
- 双指缩放：元素框保持在安全区内；小于最小值/超过最大值时有轻触反馈，不允许露出空白。
- 退出时草稿自动保存；顶栏可短暂出现 `Saved`，不使用阻断 toast。

### 3.3 E03 · 页面管理器

`Pages` 打开底部半屏（大屏可全屏）管理器。缩略图为 2 列，使用低清缓存。

- 固定页：封面、献词、目录、章节开场、结尾的锁形标识；不可删除/移动时解释原因。
- 照片页与注记页提供长按拖动、复制、删除。拖动目标仅显示合法插入位置。
- 新建页先选择 `Photo page / Note page`，再选择章节；默认插在当前章节最后一页。

### 3.4 E04 · 图片编辑与裁剪

裁剪为独立的沉浸模式：固定元素框，背景用 72% 深绿遮罩；图像容器内照片可单指平移、双指缩放。顶部 `Cancel / Crop photo / Done`，底部显示 `Reset`。

- Cancel 恢复进入裁剪前状态；Done 合并为一条撤销记录。
- 替换保留元素位置、旋转和层级，重置新图裁剪为 `Fill`。
- `Remove from page` 只移除这个元素，必有可撤销提示；不触碰系统相册或章节选片。

### 3.5 E05 · 文本编辑

`Text` 弹出轻面板，显示当前页面允许的文本字段。焦点在文本输入时，画布缩小但不被键盘遮挡；编辑完成或失焦才自动保存。

- 页面文字采用模板 token；只允许 Small / Default / Large，不给自由颜色与字体选择。
- 可拖动文本限于模板安全锚点；红色文本溢出提示包括 `Fit text`，导出前为阻断问题。
- 用户备注占位：`A few pages from the days you chose.`；不提供自动代写或宠物口吻。

### 3.6 E06 · 模板与版式

`Style` 展示 5 张样式卡；切换立即作用当前画布。

| 模板 | 背景 / 文字 | 图片处理 | 版式语气 |
| --- | --- | --- | --- |
| Warm Paper | Paper / Ink | 原色、圆角轻边框 | 安静的纸本纪念 |
| Quiet Night | Ink / Paper | 原色略降饱和 | 深色夜读、暖白文字 |
| Field Notes | Sage / Ink | 卡片、日期标记 | 手记与时间记录 |
| Cinema | 近黑白 / Paper | 低饱和、满版 | 克制电影感 |
| Film Album | Paper / Ink | 胶片白边、日期框 | 可打印的手作感 |

`Layout` 仅改当前照片页；选项为 Single、Two-up、Grid 2×2、Grid 3×2、Note。切换前显示“将移动 2 张照片到本章节新页”，确认才执行。全册模板改变 token，不改变已手调图片框/裁剪/文字。

### 3.7 E07 · 自动排版与 Book Check

Auto arrange 是确认式操作：范围 `This page / This chapter / Entire book`；摘要准确展示“影响 6 页，新增 1 页，保留 4 个手动调整”。确认按钮为 `Arrange 6 pages`。

Book Check 以问题清单表达，不擅自修复：

- 阻断：Missing photo、Text overflow、No exportable photo。
- 建议：Possible duplicate、May print softly、Watermarked sample。
- 每项有 `Go to page`；通过时显示 `Your book is ready to preview`。

### 3.8 E08 · 阅读预览与导出准备

阅读模式全屏，页面可左右滑动/点击翻页，页面本身保持纸张比例。无编辑框和工具条，顶部只有 Back、`8 / 18`、More。

- 免费状态：仅 6–8 页样章，使用真实用户照片，重复对角水印 `TAILOR · PREVIEW`；底栏 `Unlock full album · $19.99` 和 `Back to edit`。
- 已解锁/Debug：完整无水印，底栏 `Export PDF`；弹出纸张选择 A4 / US Letter 与页数、文件大小预估。

### 3.9 E09 · 导出完成与档案

渲染使用全页进度：`Rendering page 4 of 18`；取消不删除草稿。成功页展示封面缩略、生成时间、纸张与页数；主按钮 `Save and share PDF`，次按钮 `Open in archive`。失败页说明可恢复原因和 `Try again / Return to edit`。

## 4. 核心状态清单

| 状态 | 必须视觉反馈 |
| --- | --- |
| Loading document | 骨架缩略图与“Opening your book…”；不得白屏 |
| 无可入册照片 | 空页说明 + 回照片确认入口 |
| 选中图片 | 陶土选框、控制点、Photo 工具上下文 |
| 裁剪中 | 模板页面锁定、图片可移动、Cancel / Done 明确 |
| 文本溢出 | 错误色边框、可见提示、Book Check 阻断 |
| 缺失资产 | 灰色占位 + Replace；预览/导出前阻断 |
| 自动排版确认 | 影响摘要 + 可撤销承诺 |
| 水印预览 | 反复低对比水印，非单一角标 |
| 购买取消/失败 | 回到同一页预览；编辑草稿不变 |
| 导出失败 | 不显示半成品为可分享文件；保留草稿与选择纸张 |

## 5. 研发交付契约

页面的数据锚点、裁剪和文字不能由 SwiftUI 和 PDF 分别猜测。`MemoryBookDocument → Page → Element` 输出以下平台无关字段：`normalizedFrame`、`cropScale`、`cropOffset`、`rotation`、`zIndex`、`styleOverride`、`isLayoutLocked`。

SwiftUI 预览与 PDF renderer 共享 `PageStyle` token、纸张安全区、图片 `Fill` 算法、字体映射、背景填充与水印规则。任一模板必须在 A4 / Letter 下验证同一文档的视觉误差符合 PRD §7.3。

