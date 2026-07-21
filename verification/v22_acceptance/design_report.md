# Tailor v2.2 独立设计验收报告

- 验收日期：2026-07-21
- 冻结基线：`Tailor-v2.2-docfreeze-2026-07-21`
- 验收角色：独立设计验收（不采信研发自报，不修改生产代码）
- 设备：iPhone 16 Simulator / iOS 26.5；后续截图因并行 QA 关闭 Simulator 未完成
- 总结论：**FAIL，不允许以“逐页设计验收完成”进入下一阶段**

## 1. PRD 与原型输入确认

冻结确认单列出的 10 个 SHA-256 均与当前工作区逐字节一致：

| 输入 | 结果 |
|---|---|
| `Tailor_v2_PRD.md` | PASS |
| `prototype_map.html` | PASS |
| `flow_and_screen_contract.md` | PASS |
| `state_matrix.md` | PASS |
| `v2_pages_01_06_contract.md` | PASS |
| `v2_visual_contract_01_06_18_20.md` | PASS |
| `prd_prototype_traceability.md` | PASS |
| `detailed_state_specs.md` | PASS |
| `v22_adjudication_state_specs.md` | PASS |
| `v22_adjudication_states.html` | PASS |

因此，**需求及新功能如何融入原产品方案已经确定**，不存在需要产品再次裁决的 P0 歧义。实现与验收必须以这套冻结文件为唯一基线，不能再以旧 v1 截图、旧 UI 测试文案或研发口头说明替代。

## 2. 独立证据

### 自动化

- `TailorTests`：**154/154 PASS**，覆盖 v2.2 数据契约、03–09 事务、八类 checkpoint、manual asset、generation/stale、sensitive approval、revision/paper/rules key、ReturnContextStack、共享 Reader/PDF render manifest、编辑器持久化等。
- 关键 UI 回归批次：9 项中 **3 PASS / 6 FAIL**。
  - PASS：Book Check suggestion 忽略/撤销；Page Layout 明确选择；Photo Crop Cancel/Done。
  - 真实断言失败：购买 fixture 无法到达 18；Manual Import 流程仍按旧权限按钮断言；Pages 仍按旧 `Structured page` 文案断言。
  - 基础设施失败：后续 3 项因并行任务关闭/移除 Simulator App，不能计入产品失败，也不能计入 PASS。
- UI 失败后 xcresult 又出现 `mkstemp: No such file or directory`，本批次不能作为完整逐页签字包。

### 运行截图

- 当前成功保存：`runtime/06-review-sensitive.png`。
- 该截图证明 06 主页面可运行，也直接暴露横向状态栏在 390pt 宽度下右侧被截断的问题。
- 03–05、07–20 的本轮截图因共享 Simulator 被另一验收任务关闭而未生成，统一按 NOT RUN 处理，不使用旧截图冒充当前构建证据。

## 3. 逐页检查（03–20）

状态说明：PASS 表示当前证据足以确认合同；FAIL 表示存在已定位偏差；NOT RUN 表示代码结构存在但本轮无独立运行证据。

| 页面 | 结构/文案/CTA | 返回与层级 | 结论 | 依据与待复测 |
|---|---|---|---|---|
| 03 Pet Profile | profile、狗/猫、年份、Continue、Save for later 均接入 checkpoint | 02↔03、保存→20 代码存在 | NOT RUN | 数据事务 PASS；需当前构建整页截图与返回实测 |
| 04 Reference / Manual Import | 正常 3–5；手动 3–500、私有副本、直接 Needs review、CTA 禁用规则均已实现 | 代码为 manual 04→06、Back→03 | FAIL | 旧 UI 测试在 02 的入口即失败，且没有可独立直达的 manual 04 fixture；无法签 S01/S02 |
| 05 Scan | Pause/Resume、Continue later、错误恢复、换行和保存提示存在 | checkpoint 恢复代码存在 | NOT RUN | 需运行态/暂停/中断/低电/失败/完成全套当前截图与交互 |
| 06 Review | High/Needs review/Sensitive/Excluded/Stale、批量通过、敏感二次确认、stale 不入册代码均存在 | manual Back→04、normal Back→05；Save→20 | FAIL | 当前截图中状态 tab 右侧被裁切；Sensitive sheet 与 stale 冷恢复未跑；generation 标识未形成清晰可见诊断信息 |
| 07 Smart Draft | 正确说明只使用批准照片、不编造；统计、fallback、Continue later 存在 | 06↔07、07→08 | NOT RUN | StoryPlanDraft 边界单测 PASS；需当前整页截图和失败态 |
| 08 Story Plan | 章节、顺序、合并、拆分、隐藏、影响摘要已实现 | Back→07、首次→09、Save→20 | NOT RUN | mutation 单测 PASS；需当前整页及 merge/split/hidden 运行证据 |
| 09 Book Style | 五模板、同页 Letter/A4、默认 Letter、首次原子创建、失败重试、Save later 均存在 | 首次 Back→08，成功→10 | NOT RUN | 09 原子事务与 A4 首建单测 PASS；需 Letter/A4/失败/恢复截图 |
| 10 Book Preview | 共享页面模型、水印、Style/Customize/Paper/Contents、Check CTA 存在 | 10↔11、10→17 | NOT RUN | 批次中基本 Preview 标题曾通过；S12 单时期 3 张真实 6 页没有专用 UI fixture，不能签新增裁决状态 |
| 11 Page Editor | 首屏页选择、Undo/Redo、Pages/Layout/Photo/Text/Style 均存在 | 10/17/19 来源框架存在 | PASS（主画布） | editor 主画布在批次中可见；但 11→16→11 单列于 16 判 FAIL |
| 12 Pages | 页面缩略图、增加、复制、重排、删除、结构页保护均存在 | Done→11 | FAIL | UI 测试在 `Structured page` 断言失败；需确认 fixture 页锁定事实与新文案，再重跑 |
| 13 Photo Edit | 选中、拖动、缩放、双指旋转、fit/fill、裁切、替换、删除、层级、锁定均存在 | Cancel/Done→11 | PASS | Crop UI 实测 PASS；相关几何/持久化单测 PASS |
| 14 Text Edit | 选中、自由字号、字体/颜色/对齐、添加、删除、层级、锁定、旋转手柄均存在 | Back/Done→11 | NOT RUN | 数据与文字渲染单测 PASS；本轮 UI 因 Simulator 中断未完成 |
| 15 Page Layout | Single/Two-up/2×2/3×2/Note 与 Apply/Cancel 存在 | 只返回当前 11 页面 | PASS | 当前 UI 测试实测 PASS |
| 16 Apply Style / Regenerate | Editor 内有 Style sheet 与作用域能力 | 冻结要求临时 context frame 后先回 11 | FAIL | `pageEditorStyle` 只定义未 push；生产代码只对根来源 push ReturnContextStack，S10 冻结合同未落地 |
| 17 Book Check | blocker/suggestion、风险确认、Ignore/Undo、Go editor 存在 | 通过→18/19，blocker→11 | FAIL | suggestion UI 实测 PASS；但 S06/S11 所需 `CHECKING LATEST EDITS`/纸型真实进度中间态未实现为可见页面，当前是同步 evaluate 后跳转 |
| 18 Purchase | Passed revision/paper/rules、StoreKit price loading/failure、Restore、禁用购买存在 | Cancel/失败→17，成功→19 | NOT RUN（P0） | direct fixture 因没有当前 revision 的持久化 pass 被 guard 重定向 17；验收 fixture 未同步门禁，无法取得 18 运行证据 |
| 19 Final Preview & Export | 完整无水印 Reader、纸型切换、PDF 入口存在 | 19→11 编辑，导出→完成子态→20 | FAIL | 纸型会新 revision 并回 17，但没有冻结要求的复检进度中间态；Final Preview 的 Style 走 09 并回普通 Preview，未保留 19 return context |
| 20 Archive | 单一动态主 CTA、checkpoint summary、PDF、Refresh/Delete/Settings 存在 | 八类 resumeRoute 数据映射 PASS | NOT RUN | 八类数据单测 PASS；缺八类 UI fixture、invalid fallback 和 scan progress 恢复截图 |

## 4. 编辑器原能力回归

结论：**没有被阉割，但尚不能宣称完整 UI 验收通过。**

| 能力 | 证据 | 结论 |
|---|---|---|
| Pages / Layout / Photo / Text / Style 五入口 | 当前代码；Editor 首屏 UI 已出现 Pages/Photo/Text/Style；Layout UI 实测 | PASS |
| 图片选择、移动、缩放、旋转选中框 | `EditorBookPageCanvas` 的 selected-only drag/magnification/rotation；几何单测 | PASS（代码/单测） |
| fit/fill、裁切、替换、删除、z 轴、锁定 | Photo sheet、Layers、Crop；Crop UI 实测 | PASS |
| 文字添加、编辑、字体、颜色、连续字号、对齐、层级、删除、锁定 | TextEditorSheet 与 Layers；文字契约单测 | PASS（代码/单测），UI NOT RUN |
| 文字旋转手柄 | `Text rotation handle` 与中心旋转实现 | PASS（代码），UI NOT RUN |
| Undo/Redo | 主画布按钮与历史事务测试 | PASS（代码/单测） |
| 页面管理 | 能力存在，但旧 UI 文案断言失败 | FAIL，需复测 |
| 10/17/19→11→16→11 ReturnContextStack | `pageEditorStyle` 未入栈 | FAIL（P0） |

## 5. 缺陷与优先级

### P0

1. **S10 ReturnContextStack 未完成**：`pageEditorStyle` 没有任何 push 调用，11→16→11 的冻结反馈与冷恢复无法成立。
2. **S11/S06 复检中间态缺失**：保存编辑或切纸型后同步检查并直接路由，没有 `CHECKING LATEST EDITS`、新 revision/纸型/真实进度和失败恢复页面。
3. **18 Purchase 验收 fixture 失效**：新门禁会把 direct purchase fixture 重定向到 17，导致购买页无法独立验收；必须给 fixture 建立相同 revision/paper/rules 的 pass result。
4. **v2.2 裁决状态 UI 覆盖不足**：S01–S12 仅部分有 fixture；尤其 S03/S04/S06/S07/S09/S10/S11/S12 无完整当前构建证据。

### P1

1. 06 横向状态 tab 在 390pt 视口右侧截断，首屏可见层级不完整；证据：`runtime/06-review-sensitive.png`。
2. UI 测试资产与新实现漂移：Manual Import 仍断言旧按钮，Pages 仍依赖旧 fixture 锁定文案，routes 09–12 仍假设 Purchase 可无 pass 直达。
3. 06 stale 摘要缺少用户可理解的当前 generation 标识，只有变化原因和数量。
4. 19 从 Style 修改后的返回目标为普通 10 Preview，不是带原 logical page 的 19→复检→19/17。

## 6. 放行条件与需复测页面

修复顺序必须是：

1. 先补 S10、S11/S06 的生产路由与可见中间态。
2. 再同步 UI fixture 和断言，使 Purchase、denied manual、Pages、八 checkpoint 均可确定性到达。
3. 重新获取 03–20 当前构建整页截图；每页包含状态栏、导航、主体、底部 CTA。
4. 优先复测：**04、06、10、12、14、16、17、18、19、20**。
5. 完成 12 个 v2.2 新增裁决状态的成功/失败/恢复分支后，才可改为设计 PASS。

当前可以确认的是：**PRD 与原型已经冻结且信息充足；代码的数据层和编辑器主体能力较完整；但设计实现门禁仍有 P0，不能开始发布或宣称逐页高保真验收完成。**
