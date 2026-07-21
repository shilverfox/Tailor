# 需求理解：自动成册 + 完整页面编辑器

## 1. 产品范围

本需求不是新增一个孤立的“自动排版页面”，而是重构相册制作主链路：

`已确认照片 → 故事规划 → 自动初稿 → 页面级预览 → 自由编辑 → Book Check → 一比一 PDF`

自动初稿降低开始成本，自由编辑保证个性化，Book Check 保证成品质量，共享渲染保证用户看到的就是导出的。

## 2. 能力边界

### 2.1 自动生成层

- 按时间间隔、地点（用户授权时）、视觉近似与用户章节归并事件。
- 为照片计算编辑用途：`hero / supporting / sequence / detail / duplicate / lowQuality`。
- 每页从页面配方中选择候选布局，依据照片数量、横竖比、主体安全区、清晰度和整书节奏评分。
- 生成封面、献词、目录、章节开场、照片页、注记页和结尾页。
- 自动结果全部可撤销、可修改；不得写入推断性情感文案。

### 2.2 页面编辑层（不得删除）

图片支持：选中、移动、双指等比缩放、双指旋转、调整元素框、替换、删除、裁切、前移、后移、置顶、置底、锁定。只有当前选中元素响应编辑手势。

文字支持：添加、选中、输入、移动、连续字号调整、颜色、允许字体集、对齐、层级、删除、锁定；通过选中框的旋转柄围绕中心点自由旋转。打开属性面板时不得默认唤起键盘，只有点击正文输入区才获得焦点。

页面支持：新增、复制、删除允许删除的页面、重排、锁定、选择页面配方、撤销、重做、自动保存。

### 2.3 模板层

五套模板必须同时区别：字体系统、背景、图片处理、边框、留白、页面配方权重、章节节奏和装饰信息。

| 模板 | 主要排版语言 |
| --- | --- |
| Warm Paper | 暖白纸张、大留白、单图/双图、陶土日期 |
| Quiet Night | 深绿背景、暖白字、少图聚焦、低饱和照片 |
| Field Notes | 日期/地点/编号/线条、记录式卡片 |
| Cinema | 满版、低饱和或黑白、宽画幅、字幕式文字 |
| Film Album | 相纸白边、轻微旋转/叠放、手写日期、手作感 |

模板应用有两种模式：`Visual style only` 和 `Rearrange unlocked pages`。手工编辑页一旦产生显著变化即默认 `isLayoutLocked = true`。

## 3. 页面与入口

| 页面 | 入口 | 核心动作 | 退出结果 |
| --- | --- | --- | --- |
| Smart Draft | Photo Review 创建 | 生成并持久化 `StoryPlanDraft`，不创建页面 | 进入 Story Plan |
| Story Plan | Smart Draft 完成 | 编辑并确认章节语义；首次仍不创建页面 | 进入 Book Style；已有文档则标记相关页 needsReflow |
| Book Style | 首次 Story Plan 确认或后续 Style | 首次以 StoryPlanDraft + 模板原子创建完整 MemoryBookDocument；后续安全应用模板 | 打开整书预览 |
| Book Preview | 初稿/编辑器 Preview | 翻页、选择页面、Customize | 进入页面编辑器 |
| Page Editor | Customize/点击页面元素 | 完整图片、文字、页面编辑 | 自动保存并回到预览 |
| Page Recipe | Editor / Layout | 当前页候选配方 | 应用并可撤销 |
| Apply Style | Editor / Style | 仅视觉或重排未锁页 | 返回整书预览 |
| Book Check | Preview / Check | 定位并处理问题 | 通过后允许导出 |
| Final Preview | Book Check 通过 | A4/Letter 最终检查 | 生成 PDF |

## 4. 状态要求

- `generating / generated / generationFailed / cancelled`
- `clean / userEdited / layoutLocked / missingAsset`
- `saving / saved / saveFailed / recovered`
- `previewing / renderingPDF / exportFailed / exported`
- `bookCheckPassed / warning / blocking`

App 被杀死、切后台或设备重启后，必须恢复到最近一次成功保存的文档版本；不得重新自动排版覆盖用户编辑。

## 5. 数据与内容规则

- 原图仍由 PhotoKit `localIdentifier` 引用，不复制、不上传、不修改。
- 排版数据使用归一化坐标，不能存屏幕 pt 作为唯一值。
- `neverUse`、敏感、隐藏时期和排除照片在生成、预览、编辑候选和 PDF 层均再次过滤。
- 文本来源必须记录为 `user / metadata / neutralSystemLabel`，不增加生成式情感文案来源。

## 6. 验收结果

- 自动初稿不再以重复六宫格为主，至少形成章节开场、Hero、Sequence、Quiet Pause 等节奏。
- 五模板用黑白轮廓仍可辨认，不依赖颜色标签识别。
- 任一自动页面都可进入完整编辑器继续编辑。
- 预览和 PDF 的图片框、裁切、旋转、层级、文字与分页一致。
