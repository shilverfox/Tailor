# 可派工任务拆解

## Milestone 0：冻结共同契约（必须最先完成）

| ID | Owner | 任务 | 输出 | 验收 |
| --- | --- | --- | --- | --- |
| P-01 | 产品 | 评审 `01_requirement_understanding.md`，关闭 P1-01～06 | 决策记录 | 无相互冲突的产品规则 |
| D-01 | 设计 | 补自动生成原型到完整编辑器的入口、返回和状态 | E01–E09 可点击原型 | 主流程无断点 |
| I-01 | iOS | 定义 Document/Page/Element、schemaVersion 和 fixture | 模型代码与 JSON fixture | 可编码/解码且字段不丢失 |
| Q-01 | 测试 | 固化 4 套黄金 fixture 和验收矩阵 | 数据、预期、基准目录 | 5 模板 × 2 纸张可重复执行 |

## Milestone 1：共享渲染垂直切片

| ID | Owner | 任务 | 输出 | 验收 |
| --- | --- | --- | --- | --- |
| D-02 | 设计 | Warm Paper 的页面 token、网格、安全区、字体和配方标注 | 设计标注 | 390×844、A4、Letter 均有规则 |
| I-02 | iOS | 实现 ResolvedPage 与 ImagePlacementResolver | 渲染核心 | Fit/Fill/crop/rotation 单测通过 |
| I-03 | iOS | 用同一 fixture 驱动 SwiftUI 与 PDF | Demo + PDF | 核心几何误差 ≤ 1 pt |
| Q-02 | 测试 | 截图/PDF 基准比较 | 首轮报告 | 差异可定位到 pageID/elementID |

## Milestone 2：自由编辑器完整接入

| ID | Owner | 任务 | 输出 | 验收 |
| --- | --- | --- | --- | --- |
| D-03 | 设计 | 图片、文字、页面、图层、锁定、Undo 的状态稿 | 标注与动效说明 | 覆盖空/选中/编辑/错误态 |
| I-04 | iOS | 统一 SelectionStore 和手势仲裁 | 可运行编辑器 | 只有选中元素响应编辑 |
| I-05 | iOS | 图片移动、缩放、旋转、裁切、层级、替换、删除 | 功能代码 | T-03～T-05、T-08 通过 |
| I-06 | iOS | 文字连续字号、颜色、字体、旋转柄、层级、删除 | 功能代码 | 面板不抢焦点；预览/PDF 一致 |
| I-07 | iOS | Undo/Redo、自动保存、锁定和恢复 | 文档事务层 | T-09～T-11 通过 |
| Q-03 | 测试 | 全量编辑交互与重启恢复 | 回归报告 | P0 用例无阻断 |

## Milestone 3：自动生成和模板系统

| ID | Owner | 任务 | 输出 | 验收 |
| --- | --- | --- | --- | --- |
| P-02 | 产品 | 定义 Hero/Sequence/Quiet 等可解释规则 | 规则表 | 不含推断性情感内容 |
| D-04 | 设计 | 5 模板完整设计系统和各 6 张代表页 | 30 张基准页 | 灰度仍可识别模板 |
| I-08 | iOS | EditorialProfile 与确定性事件/角色分析 | 分析模块 | 输出稳定、可解释、可取消 |
| I-09 | iOS | PageRecipe、评分器和 Book Planner | 自动初稿 | 通过自动质量指标 |
| I-10 | iOS | Visual-only / Rearrange-unlocked 应用与 diff | 模板切换 | 锁定页零变化，一步可撤销 |
| Q-04 | 测试 | 20 份黄金册首稿盲评 | 评分报告 | 无敏感素材泄漏；达质量门槛 |

## Milestone 4：Book Check、最终预览与发布门禁

| ID | Owner | 任务 | 输出 | 验收 |
| --- | --- | --- | --- | --- |
| I-11 | iOS | Book Check 规则、导航和阻断 | 检查模块 | 每个 issue 可定位并修复 |
| I-12 | iOS | A4/Letter 最终预览、PDF 原子导出 | 导出链路 | 离线成功；失败无半成品 |
| D-05 | 设计 | 最终预览、错误和恢复态验收 | 视觉签字 | 与原型/标注一致 |
| Q-05 | 测试 | 主流程、异常、性能、像素、真机回归 | 发布报告 | `07_delivery_gates.md` 全部通过 |

## 派工字段要求

每个研发任务进入执行前必须补：代码模块/文件、输入 fixture、日志字段、失败降级、单元测试、UI 测试和回滚开关。不得只写“实现自动排版”这种不可验收任务。

