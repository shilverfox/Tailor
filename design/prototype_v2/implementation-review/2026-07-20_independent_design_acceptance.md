# Tailor v2 独立设计验收报告

日期：2026-07-20  
验收范围：Smart Draft、Story Plan、五模板、Page/Text Editor、Book Check、Purchase、Final Preview  
对照基线：`Tailor_v2_PRD.md`、`MemoryBook_v2` 交付文档、`design/prototype_v2/detailed_states.html` 与当前 SwiftUI 实现  
结论：**不通过，不能宣告 v2 高保真设计验收完成。**

## 1. 验证环境与证据

- Git 基线：`4aa8283`；工作区存在尚未提交的 v2 代码和文档变更，本报告按当前工作区验收。
- Xcode：26.6。
- 运行设备：iPhone 17 Pro Simulator，iOS 26.5。
- 构建命令：`xcodebuild ... build CODE_SIGNING_ALLOWED=NO`。
- 构建结果：`BUILD SUCCEEDED`。
- UI 文本编辑专项：`testEditorTextUsesWhitelistedFieldsAndRoleSpecificAdd` 运行失败，测试过程中 App 意外退出；不能将文字属性面板判定为通过。
- 本轮运行截图：
  - `runtime/01-smart-draft.png`
  - `runtime/02-story-plan.png`
  - `runtime/03-book-style.png`
  - `runtime/04-page-editor.png`
  - `runtime/05-book-check-400ms.png`
  - `runtime/06-purchase.png`
  - `runtime/07-final-preview.png`

说明：本轮没有建立 390×844 原型与运行截图的逐像素叠加基线，也没有真实 PhotoKit 资产、真机 StoreKit 与导出 PDF 的三方截图。因此“页面可见”不等于“一比一还原通过”。

## 2. 页面级结论

| 模块 | 当前可确认结果 | 与 PRD / 详细原型差异 | 结论 |
|---|---|---|---|
| Smart Draft | 成功态可达；标题、摘要、说明和 CTA 可见 | 成功态的编辑节奏与原型明显简化；失败、重试、简易时间线降级、稍后继续没有运行截图 | 部分通过，关键状态缺证据 |
| Story Plan | 章节时间线、日期、代表图、标题、照片数和隐藏入口存在 | 主界面没有可发现的章节排序、合并、拆分、`needsReflow`；章节编辑器只支持标题、备注、封面、照片增删/照片内排序 | 不通过 |
| Book Style | Warm Paper、Quiet Night、Field Notes 运行态可见；代码定义五模板 | Cinema、Film Album 未在本轮运行截图中可见；没有五模板完整页面族、灰度盲测或真实照片差异证据 | 部分通过，缺证据 |
| Page Editor | 编辑器壳层、页码、Undo/Redo、页面轨道和底部工具栏可达 | fixture 使用无效 PhotoKit ID，画布不能显示真实照片；无法进行图片裁切、边界、选择态和模板高保真验收 | 部分通过，关键素材缺证据 |
| Text Edit | 代码存在角色白名单、连续字号/字体等入口 | 专项 UI 测试在选择 photoCaption 后 App 意外退出；8 字体、连续字号、颜色、对齐、旋转柄、进入不弹键盘均无完整运行证据 | 不通过 |
| Book Check | 阻断态可达；评分、阻断/建议数量、问题卡可见 | 所有问题只执行通用 `editBook()`；没有携带 issue/page/element/index；没有建议忽略、风险确认、撤销忽略；通过态无 fixture | 不通过 |
| Purchase | 一次性购买说明、权益、购买与恢复入口可见 | 页面写死 `$19.99`，没有使用 StoreKit 本地化价格；失败、取消、pending、离线、恢复运行证据不完整 | 不通过商业化门禁 |
| Final Preview | 无水印阅读器壳层、内容目录、Style/Paper、页码、PDF CTA 可达 | Edit 返回 Book Check，不返回 Page Editor；普通 Preview 的 Edit 返回 Story Plan；没有真实照片、A4/Letter、最终 PDF 一致性证据 | 不通过 |

## 3. 阻断缺陷

### P0-01 Preview / Final Preview 的编辑导航错误

- 普通 Preview 的 `back` 被配置为 Story Plan；Final Preview 的 `back` 被配置为 Book Check。
- `PreviewFeatureView` 顶部 `Edit` 与返回箭头共用同一个 `back()`。
- 结果：用户不能按 PRD 从 Preview/Final Preview 直接返回 Page Editor；Final Preview 也无法形成“编辑后以最新 revision 再导出”的闭环。
- PRD 对照：§3 返回规则、§4.10、§4.19。

### P0-02 Story Plan 缺少结构编辑能力

- 运行页面只提供点击章节和长按隐藏/显示。
- 当前章节编辑器可改标题、备注、封面、章节内照片，但没有章节合并、拆分及全局章节顺序操作。
- 没有 `needsReflow` 的可见状态与“锁定页保持不变”反馈。
- PRD 对照：§4.08；详细状态 03–05。

### P0-03 Book Check 无法精确定位问题并返回原位置

- 问题卡虽然显示 `Page X · Open in editor`，实际点击仅调用无参数 `editBook()`。
- 没有传递 `issueID + pageID + elementID + issueIndex`，也没有返回后恢复原问题滚动位置的状态。
- PRD 对照：§3、§4.17；详细状态 11。

### P0-04 Book Check 建议不可忽略

- standalone Book Check 中阻断与建议都只显示为进入编辑器的按钮。
- 没有 suggestion-only 的 Ignore、风险说明、用户选择记录、`Ignored by you` 和撤销入口。
- PRD 对照：§4.17；详细状态 12。

### P0-05 Text Edit 专项 UI 回归崩溃/意外退出

- `testEditorTextUsesWhitelistedFieldsAndRoleSpecificAdd` 在点击 `Text field photoCaption` 后测试进程报告 App unexpected exit 并失败。
- 在修复并重新取得截图/交互证据前，不能验收 Text Edit。

### P0-06 Purchase 价格不是 StoreKit 本地化价格

- 页面直接渲染 `$19.99 · One-time purchase`。
- 不满足实际商品、地区货币和 App Store 本地化价格要求；可能造成展示价格与实际结算价格不一致。
- PRD 对照：§4.18。

### P0-07 导出页仍暴露 v2 明确排除的视频功能

- `ExportFeatureView` 仍显示 `Create 30-second memory video` / `Share 30-second video`。
- v2 PRD 明确将视频、背景音乐排除在范围外，当前实现会让产品边界和测试范围再次分叉。
- PRD 对照：§1.3。

## 4. P1 视觉与体验问题

### P1-01 Smart Draft 成功态表现弱于详细原型

当前页面主要是线性数据行和说明卡，缺少原型中更明确的编辑摘要、生成节奏和故事结构预期。信息正确，但尚不足以支持“自动生成质量”作为核心卖点。

### P1-02 五模板没有形成可验收的完整差异证据

本轮只看到前三个模板卡。没有 Cinema / Film Album 的运行态截屏，也没有每个模板的封面、章节开场、单图、双图、拼贴、结尾页对照。PRD 的“任意两模板至少 3 个结构差异”和灰度识别率 ≥80% 尚无证据。

### P1-03 编辑器 fixture 无真实照片

页面缩略图和画布出现占位，无法验证图片比例、裁切策略、旋转后外框、层级、锁定与样式一致性。设计验收必须改用真实可访问 PhotoKit 资产或稳定的测试图片注入层。

### P1-04 页面轨道标签可读性不足

编辑器底部 `chapterOpener` 等类型文本出现截断，末端页也部分裁切。横向滚动本身可接受，但缩略图名称不应成为主要信息噪声；应优先显示页码、章节名或可读的短类型名。

### P1-05 Final Preview 缺少最终性确认信息

当前阅读器能翻页，但没有明显展示当前纸张尺寸、保存 revision、Book Check 已通过/已解锁状态。详细原型中的最终确认感被削弱。

## 5. 明确缺少的运行证据

以下项目不能因为“代码中有类型、分支或单元测试”而判定设计通过：

1. Smart Draft：失败、重试、简易时间线降级、取消/稍后继续与恢复。
2. Story Plan：相邻章节合并、拆分点选择、章节级排序、`needsReflow`、锁定页 unchanged。
3. 五模板：Cinema、Film Album 以及五模板完整页面族和灰度盲测。
4. Text Edit：8 字体逐项、连续字号、颜色、对齐、层级、删除、旋转柄、长文本溢出、打开面板不自动弹键盘。
5. Regenerate：默认只处理 `needsReflow` + 未锁页、整书二次确认、恢复快照、单次 Undo。
6. Book Check：全部通过、精确跳转和返回原问题、建议忽略/撤销。
7. Purchase：StoreKit 真商品、本地化价格、失败、取消、pending、离线、恢复购买。
8. Final Preview/PDF：真实照片、A4/US Letter、完整无水印逐页预览、Preview/SwiftUI/PDF ≤1 pt 对照、取消和 Share Sheet 真机。
9. Archive：v1 草稿迁移失败、PDF 缺失、保留编辑并重新导出。
10. Accessibility：Dynamic Type、VoiceOver 阅读顺序、非颜色状态表达。

## 6. 建议修复顺序

1. 先修 P0-01、P0-03、P0-04，打通 Preview → Editor → Book Check → Final Preview 的可逆闭环。
2. 补齐 Story Plan 合并/拆分/排序/needsReflow，再验收 Smart Draft 到初稿生成的数据链。
3. 修复 Text Edit 意外退出，建立带真实图片的 Editor fixture。
4. 让 Purchase 使用 StoreKit 本地化商品价格，并移除 v2 范围外的视频入口。
5. 建立五模板页面族截图和 Final Preview/PDF 同源对照，再做像素级视觉验收。

## 7. 当前可给出的门禁结论

- 工程可编译：**通过**。
- 核心页面能直达：**部分通过**。
- PRD 功能闭环：**不通过**。
- 详细状态原型覆盖：**不通过，多个关键状态缺实现或缺证据**。
- 高保真视觉还原：**缺少可比较基线，不能宣告通过**。
- 可进入下一步全量研发完成/发布：**不建议**；应先关闭 P0 并补齐证据。

---

## 8. 第二轮返修复验（2026-07-20 21:51–22:07）

复验对象：研发冻结后的当前工作区。Git HEAD 仍为 `4aa8283`，但 `AppContainer`、Domain、Features、Services 与 Tests 均存在未提交返修改动，因此本节以**复验时工作区内容**为唯一基线。

### 8.1 新增证据

- 最新代码重新构建：`BUILD SUCCEEDED`。
- 运行截图目录：`runtime_round2/`。
- 核心截图：
  - `01-story-plan.png`：合并、拆分、Earlier/Later 入口。
  - `02-book-check.png`：Book Check 阻断态。
  - `03-purchase.png`：运行时本地化价格 `¥148.00`。
  - `04-preview.png`、`05-final-preview.png`：Preview 与 Final Preview 的 Edit 入口。
  - `11-preview-warm-paper.png`、`12-preview-quiet-night-recapture.png`、`13-preview-field-notes.png`、`14-preview-cinema-recapture.png`、`15-preview-film-album.png`：五模板最终预览。
  - `16-text-edit-before-crash.png`：Text Edit 崩溃前可见状态。
  - `17-export-no-video.png`：导出页已无视频入口。
- 定向单元测试：4/4 通过。
  - 五模板结构签名互异。
  - Story Plan 合并、拆分、排序后照片不丢失、不重复。
  - `needsReflow` 不标记锁定页。
  - 仅 suggestion 可忽略，且选择可持久化。
- Book Check 精确文字定位 UI 测试：1/1 通过。
- Text Edit 角色白名单专项 UI 测试：仍失败，App 在点击 `photoCaption` 后再次 unexpected exit。

### 8.2 首轮阻断项复验表

| 首轮项 | 返修结果 | 第二轮判定 |
|---|---|---|
| P0-01 Preview / Final Preview 的 Edit 导航错误 | `PreviewFeatureView` 已把 `Edit` 与返回箭头拆开；普通 Preview 的 Edit 调用 `openEditor(returningTo: .preview)`，Final Preview 的返回和 Edit 均进入 Editor，并通过 `editorReturnRoute` 回到原流程 | **代码关闭；页面入口有截图。缺一次完整点击往返录像，但不再列为 P0** |
| P0-02 Story Plan 缺结构编辑 | 页面已显示 Earlier、Later、Merge next、Split；模型测试通过；修改章节会向共享 MemoryBook 标记 `needsReflow`，锁定页保持不变 | **功能层关闭；高保真仍部分通过**。当前是行内即时操作/菜单，没有详细原型中的合并确认、拆分影响摘要与返流状态截图 |
| P0-03 Book Check 无精确定位 | 新增 `BookCheckNavigationTarget(issue, issueIndex)`，传递 page/element/field；Editor 返回 Book Check 时保留 `bookCheckFocusKey`；精确文字字段 UI 测试通过 | **关闭** |
| P0-04 Book Check 建议不可忽略 | suggestion 显示 Keep and ignore；有风险确认、Ignored by you、Undo ignore；模型持久化测试通过；blocking 无法忽略 | **代码与模型关闭；完整点击截图缺证据** |
| P0-05 Text Edit UI 异常退出 | 面板可打开，可见白名单、Add free text、preset、对齐、文本、连续字号；但同一专项测试在点击 photoCaption 后再次 unexpected exit | **仍失败，保持 P0** |
| P0-06 Purchase 写死价格 | View 接收 `displayPrice`；生产服务读取 StoreKit `Product.displayPrice`；截图显示当前 locale 的 `¥148.00` | **关闭**。真实 App Store 商品不可用/离线状态仍属于发布前测试证据 |
| P0-07 v2 导出页仍有视频 | Feature、Domain、Service 已无 video/createVideo；导出完成页截图只保留 PDF 分享、打开档案、返回时间线 | **关闭** |

### 8.3 五模板复验

| 模板 | 运行结果 | 视觉判断 |
|---|---|---|
| Warm Paper | 米白纸张、暖色纸框、克制留白 | 可辨识 |
| Quiet Night | 深墨绿纸张、暗色边框、浅色文字 | 设计语言可辨识，但两次 simulator 截图均出现顶部/底部材质层缺失与文字残片 |
| Field Notes | 淡绿横线纸、浅绿框 | 可辨识 |
| Cinema | 黑色页面、强对比文字、11 页节奏 | 可辨识 |
| Film Album | 深色相册框、虚线安全区、倾斜照片槽 | 可辨识 |

五种模板的模型签名测试通过，且封面运行截图在颜色、纸张纹理、边框和照片处理上可区分。因此“模板不是简单换色”已达到代码/单页证据门槛。仍不能宣告完整 KPI 通过，原因是：

1. 没有五模板完整页面族的真实照片对照。
2. 尚未执行 5 人 × 20 题的灰度盲测，无法证明识别率 ≥80%。
3. Quiet Night 的 `ultraThinMaterial` 工具层在 simulator screenshot 中连续两次发生合成缺失；需真机截图确认是模拟器证据问题还是实际渲染问题。

### 8.4 第二轮仍失败或仍缺证据

#### P0-R2-01 Text Edit 点击 Photo Caption 后异常退出

- 复现用例：`testEditorTextUsesWhitelistedFieldsAndRoleSpecificAdd`。
- 复现位置：Page 5 → Text → `Text field photoCaption`。
- 结果：测试进程检测到 App unexpected exit，`xcodebuild` 以 65 失败。
- 证据：`/tmp/TailorTextRound2.xcresult`；崩溃前画面为 `runtime_round2/16-text-edit-before-crash.png`。
- 影响：文字编辑是 v2 核心能力，不能按偶发测试不稳跳过；在根因关闭前，Page Editor 与整书可编辑承诺均不能验收通过。

#### P1-R2-02 Story Plan 操作形态未高保真匹配详细状态原型

- 现实现用一行小型文字按钮直接 Earlier/Later/Merge，并以 Menu 选择 Split 点。
- 详细状态原型要求合并只选相邻章节且有明确确认；拆分需展示分割点、新章节照片数和受影响页面；`needsReflow` 需明确“锁定页 unchanged”。
- 当前功能可用，但缺少防误触与影响预告，不能判定详细状态稿一比一通过。

#### P1-R2-03 Quiet Night 运行截图合成异常

- `12-preview-quiet-night.png` 与延迟复拍 `12-preview-quiet-night-recapture.png` 均出现顶部栏和底部栏大片缺失，只残留局部文字。
- 其他四模板同路径截图正常。
- 目前不能确认是 Simulator + Material 的截图合成缺陷，还是 Quiet Night 实际显示缺陷；必须补真机证据。

#### 缺证据但不回退为已知代码缺陷

- Preview / Final Preview 点击 Edit、保存后返回相同 reader revision 的完整录屏。
- Story Plan 操作后 `Pages need review` 运行截图和锁定页 unchanged 提示。
- standalone Book Check 的 Ignore 确认、Ignored by you、Undo ignore 截图。
- StoreKit 真商品、地区切换、离线、pending、取消和恢复购买。
- 五模板完整页面族、真实照片和灰度盲测。
- Final Preview / SwiftUI / A4/Letter PDF ≤1 pt 一致性。

### 8.5 第二轮门禁结论

- 首轮 7 个 P0 中：**5 个关闭，1 个代码关闭但缺完整交互证据，1 个仍失败**。
- 主导航与 Book Check 数据契约：**显著改善**。
- 五模板单页可辨识：**基本通过**；完整模板 KPI 未通过。
- Text Edit：**不通过**。
- 详细状态原型高保真：**不通过**，Story Plan 交互形态与 Quiet Night 证据仍需返修/复核。
- 第二轮总门禁：**仍不通过，不建议宣告设计验收或开发阶段结束。**

---

## 9. Reader / PDF 同源渲染专项复验（2026-07-21）

### 9.1 冻结基线

本轮先重新核对产品与原型，再检查运行证据；未以现有实现反向修改需求。适用门禁如下：

- `Tailor_v2_PRD.md` §4.10：阅读预览必须是页面级预览，不是 PDF 缩略图。
- `Tailor_v2_PRD.md` §4.14：文字字号、字体、颜色和旋转必须进入共享文档并一比一导出。
- `Tailor_v2_PRD.md` §4.14：编辑器、阅读预览和 PDF 必须复用相同 resolved font、字号、行高、字距、段距和矩形，并由共享 CoreText 结果判定换行与溢出。
- `Tailor_v2_PRD.md` §4.19：最终预览和 PDF 必须使用相同 document revision、纸张尺寸和 resolved pages。
- `Tailor_v2_PRD.md` §9：SwiftUI 与 PDF 核心几何误差必须 `≤ 1 pt`，裁切、旋转、层级、文字和分页一致。
- `prototype_map.html`：唯一主链路仍为页面预览 → 自由编辑 → Book Check → 购买 → 一比一 PDF；Final Preview 的 A4/Letter 与 PDF 同源。

因此，本轮只有在 Reader / PDF 的图片和文字几何均达到 `≤ 1 pt` 后，设计才可签署通过；“肉眼接近”不能替代门禁。

### 9.2 已确认通过的项目

- Warm Paper 的 A4 与 US Letter 各 7 页 Reader 证据均已逐页检查。
- 页面层级、章节节奏和纸张安全区清楚，没有发现新的截断或越界。
- 目录页只保留纸内 `Contents` 与目录条目；原纸内导航/CTA 浮层已移除，`QA-V2-006` 可关闭。
- 图片旋转时元素框与内容共同旋转；第 5 页覆盖了多图旋转与 zIndex 叠放，阅读顺序可辨。
- Fit/Fill 与裁切未出现非等比拉伸；图片几何量化结果通过：
  - A4：最大误差 `0.769 pt`。
  - US Letter：最大误差 `0.723 pt`。
- RTL、emoji、组合字符和连续字号样例已进入 Reader/PDF 证据；换行内容一致，没有漏字或溢出。
- 五模板 PDF 已成功生成 70 页，说明 PDF 侧的模板页面族可产出。

证据：

- Reader 第二轮截图：`/tmp/TailorP0005UIAttachments/`
- 三联复验根目录：`verification/memorybook_v2/triple_render_2026-07-21/`
- 正式指标：`verification/memorybook_v2/triple_render_2026-07-21/rerun_canonical/comparison_metrics_registered.json`
- A4/Letter 对照：`verification/memorybook_v2/triple_render_2026-07-21/rerun_canonical/contact_sheets_registered/`
- QA 正式记录：`verification/memorybook_v2/triple_render_2026-07-21/REPORT.md`

### 9.3 未通过的阻断项

#### P0-R3-01 Reader / PDF 文字几何仍超过 1 pt

第二轮修复后，仅允许对整页做刚性平移 registration 的量化结果仍为：

| 纸张 | 图片最大误差 | 文字最大误差 | 判定 |
|---|---:|---:|---|
| A4 | 0.769 pt | 2.307 pt | 图片通过；文字失败 |
| US Letter | 0.723 pt | 1.447 pt | 图片通过；文字失败 |

原始对照指标为 A4 image/text `0.769/1.538 pt`、Letter image/text `0.723/2.170 pt`。无论采用原始还是只允许整页刚性平移后的结果，文字均未满足 PRD 的 `≤ 1 pt` 硬门禁。该偏差属于页面内部文字的相对漂移，不能用继续调整整页位置掩盖。

影响：

- `QA-V2-005` 必须保持 **OPEN / P0**。
- RTL/emoji、组合字符和连续字号虽已覆盖，但在文字几何超阈值时不能签署 P-003 一比一导出。
- 当前不能宣称 Reader/Final Preview 与 PDF 高保真一致。

### 9.4 五模板证据边界

当前只有 Warm Paper 具备 A4/Letter Reader 与 PDF 的本轮三联证据。五模板 70 页 PDF 生成通过，只能证明 PDF 侧能够生成，不足以证明五模板在 Reader、最终预览和 PDF 三个表面都未回归。

因此以下两项仍未完成：

1. Quiet Night、Field Notes、Cinema、Film Album 的代表页 Reader/PDF 三联复验。
2. 五人灰度盲测识别率 `≥80%`；Quiet Night 仍需真机证据排除 Material 合成问题。

### 9.5 最终设计签字

- 页面层级：**通过（Warm Paper A4/Letter）**。
- 目录页无纸内导航浮层：**通过，关闭 QA-V2-006**。
- 图片 fit/fill、旋转与 zIndex：**通过本轮证据**。
- 文字基线、字号与几何一比一：**不通过**。
- RTL/emoji 与连续字号：**覆盖已确认，但因文字几何失败不能签署最终通过**。
- 五模板设计语言无回归：**仅 PDF 侧有完整证据；三联证据与盲测未完成**。
- 本轮总门禁：**FAIL / PENDING**。

在 `QA-V2-005` 的 A4 与 US Letter 文字几何均达到 `≤ 1 pt`，且补齐五模板三联代表页与既定盲测/真机证据前，设计不签署通过，也不能据此进入下一阶段。

---

## 10. v2.2 候选冻结文档独立审计（2026-07-21）

审计范围仅包含 PRD、原型入口、流程合同、状态矩阵、01–06 合同、01–06/18/20 视觉合同、追踪表与冻结 SHA；本节不评价当前代码实现。

### 10.1 已通过

- 冻结单列出的 8 个 SHA-256 与工作区文件全部一致。
- 产物边界一致：07 只产生 `StoryPlanDraft`，08 编辑/确认，09 选择模板和纸型后原子创建 `MemoryBookDocument`。
- 09 默认 US Letter、可选 A4；纸型属于 revision；17 检查绑定 revision、paperSize 与 rulesVersion；19 切纸型会创建新 revision、resolve 并重跑检查。
- 03–09 的八类 Archive checkpoint、动态主按钮和 03–10 resumeRoute 已统一。
- denied 手动模式统一为 02→03→04 Manual Import→06，PHPicker 选择 3–500 张，保存明确选择的 App 私有副本且不建立全库索引。
- sensitive 的 decision/sensitivity 分离、`selected + sensitiveApprovedAt` eligibility 与 neverUse 不可覆盖已统一。
- 01–06、18、20 已建立 v2 独立视觉合同；`prototype_map.html` 不再把旧 v1 页面作为这些页面的 expected baseline。
- Page Editor 的图片、文字、页面、层级、锁定和 Undo/Redo 能力保留；付费边界和 Reader/PDF 同源门禁未回退。

### 10.2 P0：returnContext 与 revision / Book Check 状态机仍不闭合

候选文档同时规定：

1. Book Check 结果绑定 `documentRevisionID + PDFPageSize + bookCheckRulesVersion`，revision 变化后立即失效。
2. 11 的编辑自动保存；17 issue 和 19 当前页均可进入 11。
3. 11 又按 returnContext 直接返回 17 原 issue 或 19 原 logicalPageID。

编辑后会出现唯一预期缺失：旧 issue 可能消失或重排，19 也不再满足“当前 revision 已通过 Book Check”的进入条件。16 从 11 进入时还需要保存 11 的父 returnContext，单层 `sourceScreen` 无法表达嵌套返回链。

文档必须统一冻结：

- ReturnContext 使用上下文栈或明确的父子结构；16 返回 11 时不得覆盖 11 的 root context。
- 编辑、布局或样式产生新 revision 后，返回 17/19 前自动执行哪一种 Book Check。
- issue fallback：原 issueID → 同页下一问题 → 全书下一问题 → pass summary。
- 19 返回链检测到 blocking 时进入 17；通过后才恢复 logicalPageID；原页因 reflow 消失时恢复最近合法页。

该项直接影响阻断检查和最终导出安全，判定为 **P0 / OPEN**。

### 10.3 P1

1. 样章定义仍同时要求 `min(8,totalPageCount)`、最少 6 页、至少两个不同时段章节页；但最小输入允许 3 张且可能全部来自同一时段。需冻结“不虚构拆段”的单时段替代页规则或明确生成器的非虚构最小 6 页结构。
2. PRD 的匹配结果键为 `petProfileID + referenceSetFingerprint + matcherVersion + assetID`，状态矩阵却规定 species 变化产生新 match generation。需明确 species 包含在 fingerprint/key 中，或增加 generationID/覆盖规则，避免同一 petProfileID 修改狗猫类型后缓存实现分叉。
3. Book Check 阈值仍称“v2.1 冻结规则”，当前文档版本为 v2.2；建议明确这是独立的 rulesVersion 标识，而不是文档冻结版本。

### 10.4 门禁结论

- 候选 v2.2 文档：**FAIL**。
- 剩余：1 个 P0、3 个 P1。
- 是否允许恢复既定 `QA-V2-005` 验证：**不允许**。先关闭 returnContext/revision P0，更新所有受影响文档并重新生成冻结 SHA；之后可恢复 005，P1 可与该次文档修订一起收口。

---

## 11. v2.2 第三轮最终文档审计（2026-07-21）

本轮只审查候选冻结文档，不包含代码或运行态验收。

### 11.1 上轮问题关闭结果

| 上轮问题 | 最终裁决 | 第三轮结果 |
|---|---|---|
| ReturnContext 与 revision/Book Check 冲突 | 使用 `ReturnContextStack`；16 从 11 进入只压临时帧并先回 11；11 保存后自动复检；17 使用稳定 issue locator 与 former index fallback；19 blocking→17，通过→原 logical page/最近页 | **CLOSED** |
| 单时段 3 张与样章结构冲突 | `min(8,total)`、正常 8/最少 6；多时期优先两个章节；单时期不虚构拆段，使用真实献词/注记页组成结构 | **CLOSED** |
| species 未进入匹配代际键 | `matchGenerationID = hash(profileID + species + referenceSetFingerprint + matcherVersion)`；结果键为 generationID+assetID | **CLOSED** |
| Book Check 规则版本与 PRD 版本混用 | 独立冻结为 `bookCheckRulesVersion = 1` | **CLOSED** |

### 11.2 全链路复核

- 20 页导航与返回上下文唯一，无直接恢复旧检查结果的路径。
- 09 默认 US Letter、可选 A4；17 绑定 revision/paper/rules；19 切纸型与编辑返回都先重新检查，阻断时不能导出。
- 03–09 八类 checkpoint 与 20 的动态 resumeRoute 一致。
- denied Manual Import、识别代际、stale decision 和 sensitive eligibility 一致。
- 01–06、18、20 使用 v2 独立视觉合同；旧 v1 只保留品牌/摄影参考属性。
- Smart Draft 不替代 Page Editor；图片、文字、页面、层级、锁定、Undo/Redo 能力及付费边界未回退。
- Reader、Final Preview 和 PDF 仍要求同 document revision、同 resolved pages 与 `≤1 pt` 双渲染门禁。

### 11.3 SHA 与最终签字

冻结单列出的 8 个 SHA-256 与当前工作区文件逐项一致。

- P0：**0**。
- P1：**0（文档语义范围）**。
- 第三轮文档门禁：**PASS**。
- 是否允许恢复既定 `QA-V2-005` 验证：**允许**。

该 PASS 只表示 PRD/原型输入可执行，不表示 `QA-V2-005`、Quiet Night 真机、StoreKit 沙盒、真实设备主流程或内容质量门禁已经通过。

---

## 12. Purchase 入口增量审计（2026-07-21）

增量复核确认：

- 主流程只保留 `10 → 17`，不存在 `10 → 18`。
- 18 的唯一进入条件为 17 对当前 `documentRevisionID + PDFPageSize + bookCheckRulesVersion` 的无阻断通过态。
- 未购买时 17 进入 18；已购买/恢复购买/Debug 时 17 进入 19。
- 18 购买或恢复成功进入 19；取消、失败或离线返回 17 的相同当前 revision 通过态，不丢失草稿。
- 购买权益不会绕过后续检查；编辑或切换纸型产生新 revision 后仍必须重新运行 Book Check。
- PRD、流程图与页面表、状态矩阵、追踪表及冻结裁决语义一致。
- 冻结单列出的 8 个 SHA-256 与当前文件逐项一致。

增量结论：**PASS**。没有新增 P0/P1；继续允许执行既定 `QA-V2-005` 验证。
