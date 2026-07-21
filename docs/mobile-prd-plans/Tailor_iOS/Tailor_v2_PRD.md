# Tailor v2 产品需求文档（统一冻结版）

> 文档状态：产品与原型实施基线  
> 适用平台：iPhone，iOS 17+  
> 生效规则：本文件是 Tailor 相册生成、编辑、预览、付费和导出功能的唯一产品基线。`Tailor_v1_PRD.md` 继续作为历史来源；与本文件冲突时以本文件为准。

## 1. 产品定义

Tailor 面向失去狗或猫、在 iPhone 相册中保留大量真实照片的用户。用户授权本地照片、提供 3–5 张参考照片，App 在设备端帮助找回并确认相关素材，再生成一本可编辑、可预览、可导出的纪念相册。

Tailor 的核心价值不是“AI 猜测宠物的一生”，而是把用户确认过的真实照片整理成一本文字可控、排版精美、最终文件可信的书。

### 1.1 核心承诺

- 只使用用户授权并确认的真实照片。
- 不上传原图，不修改或删除系统照片。
- 正常 PhotoKit 流程不复制原图；只有用户在 denied 手动导入中明确选择的文件保存 App 私有副本，并随档案删除。
- 不编造宠物行为、关系、情绪、病情、死亡原因或主观感受。
- 自动生成只是可编辑初稿，不替代用户决定。
- 页面预览和 PDF 使用同一文档与渲染规则。

### 1.2 商业模式

- 单一非消耗型内购：`tailor.life_archive.unlock`。
- 美国标准展示价：`$19.99`，实际价格与货币由 App Store 地区定价返回。
- 未购买用户可以完成选片、故事规划、自动初稿和完整编辑。
- 未购买用户只能查看 6–8 页真实照片带水印样章，不能生成完整无水印 PDF。
- 已购买或恢复购买后，可查看完整无水印最终预览并反复导出当前档案 PDF。

## 2. v2 范围

### 2.1 本期包含

- 本地相册授权、参考照片、端侧扫描、照片确认与敏感素材保护。
- 事件和时间线归并、照片编辑角色、自动生成相册初稿。
- Warm Paper、Quiet Night、Field Notes、Cinema、Film Album 五套模板。
- 完整页面编辑器：图片、文字、页面、层级、锁定、撤销与重做。
- 页面级阅读预览、Book Check、A4/US Letter 本地 PDF。
- 旧草稿迁移、进程恢复、导出文件在 App 档案内可再次找到。

### 2.2 本期不包含

- 云端 AI、账号、云同步、NAS、Google Photos、Instagram、家庭协作。
- 自动情感文案、宠物口吻、天堂来信、复活、生日/疾病/死亡原因推断。
- 视频、背景音乐、实体印刷、订阅、服务器分享链接。
- 后台自动扫描、周年提醒、每日回忆或主动推送旧照片。

## 3. 唯一主流程

```text
01 Welcome
 → 02 Privacy & Permission
 → 03 Pet Profile
 → 04 Reference Photos
 → 05 On-device Scan
 → 06 Photo Review
 → 07 Smart Draft
 → 08 Story Plan
 → 09 Book Style
 → 10 Book Preview
      ↔ 11 Page Editor
          ↔ 12 Pages
          ↔ 13 Photo Edit / Crop
          ↔ 14 Text Edit
          ↔ 15 Page Layout
          ↔ 16 Apply Style / Regenerate
 → 17 Book Check
 → [未购买] 18 Purchase
 → 19 Final Preview & Export
 → 20 Archive
```

### 3.1 关键返回路径

- 所有扫描、确认、故事规划、编辑和预览页面均可返回档案并稍后继续。
- Page Editor 返回 Book Preview 时自动保存，不弹阻断确认框。
- Book Check 的问题可跳转到具体页面和元素；修复后回到原问题位置。
- Purchase 取消或失败回到相同的水印预览/Book Check 状态，不丢失编辑。
- Final Preview 返回 Page Editor 后再次导出必须使用最新保存 revision。

导航上下文不是单一 sourceScreen，而是可嵌套的 `ReturnContextStack`。每一帧保存 source、logicalPageID/formerPageIndex、paperSize，以及 Book Check 的 ruleID+pageID+elementID+formerIssueIndex。11 内进入 16 时只压入临时 Style 帧，16 结束先回 11；离开 11 时再处理底层 10/17/19 帧。

### 3.2 Checkpoint 与恢复路由

Archive 为所有“稍后继续”的统一入口，并保存唯一 `resumeRoute`：profile 不完整→03；profile 完成但参考照不足→04；扫描未完成→05；扫描完成/有待确认照片→06；Smart Draft 暂停或失败→07；StoryPlanDraft 待确认→08；故事已确认但未选模板→09；MemoryBookDocument 已创建→10。Archive 主按钮随状态显示 `Continue profile / Choose photos / Resume scan / Review photos / Continue draft / Review story / Choose style / Continue editing`。恢复数据失效时只回退到最早需要修复的页面，不清空后续成功快照。

## 4. 页面规格

### 01–06：素材获取与确认

| ID | 页面 | 核心内容 | 主要状态与规则 |
| --- | --- | --- | --- |
| 01 | Welcome | 产品价值、创建档案、隐私入口 | 不展示价格，不自动打开照片 |
| 02 | Privacy & Permission | 本机处理、不会上传、只用确认照片 | 完整/受限/拒绝；拒绝可进入 Manual Import |
| 03 | Pet Profile | 狗/猫、名字、到家年份可选、离开年份 | 名称、类型、离开年份必填；年份 1900…当前年，到家年份不得晚于离开年份 |
| 04 | Reference Photos | 3–5 张不同年龄和角度参考照 | 重启后按 PhotoKit ID 恢复；少于 3 张不可扫描 |
| 05 | On-device Scan | 进度、数量、候选缩略图、暂停/继续 | 用户显式启动；保存进度；热状态降速而非不可恢复中断 |
| 06 | Photo Review | 高确定、待确认、敏感、排除、年份筛选 | 高确定默认选中；待确认支持批量通过；所有结果可人工纠正 |

只有符合下述统一 eligibility 的照片才能进入后续相册；未批准 sensitive、neverUse、hiddenPeriod 和 excluded 均不得进入。

手动模式：照片权限为 denied 时，03 之后复用 04 的 `Manual Import` 状态，通过 PHPicker 一次选择 3–500 张最终候选照片；这些照片不进入全相册扫描，直接以 `pending` 决策进入 06。由于 denied 状态无法持久引用 PHAsset，App 仅对用户明确选择的文件保存 App 私有原图副本，并在页面上单独说明；删除档案时一并删除。若之后获得相册权限，按内容指纹映射为 PHAsset，成功映射后删除私有副本；未映射项继续作为 manual asset。手动模式可在 06 继续追加照片，不创建全库索引。

敏感状态机：`sensitivity = normal / sensitive / neverUse` 与 `decision = pending / selected / excluded` 分开保存。敏感照片只有在详情页通过风险说明后设置 `sensitiveApprovedAt`，并同时明确选择 `selected`，才可入册；仍未确认的 sensitive 不可入册。`neverUse` 永远不可被普通确认覆盖。最终 eligibility 为 `decision == selected && !hiddenPeriod && (sensitivity == normal || (sensitivity == sensitive && sensitiveApprovedAt != nil)) && sensitivity != neverUse`，生成、候选、预览、PDF 四层使用同一规则。

识别版本规则：照片 embedding 索引键为 `assetID + featureExtractorVersion`，与宠物身份无关；`matchGenerationID = hash(petProfileID + species + referenceSetFingerprint + matcherVersion)`，匹配结果键为 `matchGenerationID + assetID`。宠物姓名/年份变化不失效识别；species、参考照集合或 matcherVersion 任一变化均创建新 generation，并复用 embedding 对全库重新匹配。旧自动分类立即失效；旧人工 decision 保留为只读 `staleDecision`，在新匹配代中重新确认前不得入册，避免把另一只宠物的旧确认静默带入。

### 07 Smart Draft

进入条件：照片确认中至少有 3 张可入册照片。用户点击 `Create memory book` 后进入。

页面展示：已选照片数、事件组数、近重复降权数、预计页数和生成步骤。超过 2 秒显示真实进度，支持 `Continue later` 和取消。失败时保留照片确认结果并提供：

- `Try again`：重新运行规划。
- `Use a simple timeline`：降级为按时间分章和安全单图/双图布局。
- `Return to photos`：回到照片确认。

Smart Draft 不重新执行全相册识别，只处理用户最终确认的照片和已有本地索引。

产物边界：Smart Draft 只生成并持久化 `StoryPlanDraft`（事件组、章节候选、照片角色、去重结果和建议页数），不在此步创建完整页面。失败重试或简单时间线降级也只替换该故事规划草稿，不覆盖既有 `MemoryBookDocument`。

### 08 Story Plan

Story Plan 继承原“生命时间线”和“章节编辑”的产品职责，统一处理整书故事结构，不承担自由页面排版。

每章展示日期范围、代表图、照片数、事件数和系统建议的编辑角色。用户可以：

- 修改章节标题和自己的说明。
- 更换代表图、调整顺序、合并、拆分、隐藏或恢复章节。
- 查看本章照片并回到 Photo Review 调整选择。
- 使用中性标题；`第一次/最爱/最后` 等标题只能由用户输入或明确确认。

影响规则：修改标题和说明直接更新文档；改变章节照片、日期边界、合并或拆分会把受影响的未锁页面标记为 `needsReflow`，不立即覆盖手工页面。

交互与状态规则：

- 合并只允许相邻章节；合并后按原日期/照片顺序去重，不丢照片。
- 拆分必须先选择明确的照片分割点，分割点两侧都至少保留一张照片。
- 排序提供明确的上移/下移或拖动入口，操作后立即持久化 `sortOrder`。
- 合并、拆分、排序和照片集合变化均展示影响摘要；只标记相关未锁页面 `needsReflow`，锁定页面内容和几何保持不变。

产物边界：首次流程中，Story Plan 编辑并确认 `StoryPlanDraft`；点击 `Create first draft` 进入 Book Style，但仍不提前物化页面。已有 v2 文档从 Book Preview 返回 Story Plan 时，修改直接更新章节语义，并仅给相关未锁页面标记 `needsReflow`。

### 09 Book Style

首次创建必须选择一个模板和纸张尺寸；默认推荐 Warm Paper，美国市场默认 US Letter，用户可切换 A4。五套模板必须改变字体、留白、图片处理、页面配方权重、章节开场和整书节奏，不允许仅换配色。

| 模板 | 页面语言 |
| --- | --- |
| Warm Paper | 暖白、大留白、单图/双图、陶土日期、纸本感 |
| Quiet Night | 深绿、暖白文字、少图聚焦、低饱和、夜读感 |
| Field Notes | 日期/地点/编号/线条、卡片和观察笔记 |
| Cinema | 满版、宽画幅、黑白/低饱和、字幕式排版 |
| Film Album | 相纸白边、轻微旋转与叠放、手写日期、手作感 |

首次选择后，以已确认的 `StoryPlanDraft + AlbumStyle + PDFPageSize` 原子创建完整 `MemoryBookDocument`，随后进入 Book Preview。`PDFPageSize` 属于 document revision。后续切换走页面 16 的安全应用流程，不创建第二套文档。

### 10 Book Preview

这是页面级阅读预览，不是 PDF 文件缩略图。支持左右翻页、页码索引和页面类型标签。

- `Customize`：进入当前页 Page Editor。
- `Story`：回到 Story Plan。
- `Style`：进入安全模板切换。
- `Check book`：进入 Book Check。
- 未购买：只允许阅读 6–8 页真实带水印样章；页码轨道可显示整册结构，但未开放页面不可查看内容。
- 已购买/Debug：可阅读完整无水印文档。

样章页数为 `min(8, totalPageCount)`，正常为 8 页、最少为 6 页；固定包含封面、目录、至少一个真实章节开场、一张真实照片页和结尾页。存在两个及以上真实时期时优先包含两个不同时段章节页；只有单一时期时不得为了满足样章结构虚构拆段，可用真实献词/注记页组成 6 页。整书不足 8 页时显示所有真实页，不复制照片、不增加虚构填充页。

### 11 Page Editor

Page Editor 是所有页面排版修改的唯一入口，自动生成不能替代它。

顶栏：返回、页码、Undo、Redo、More。底栏：Pages、Layout、Photo、Text、Style。页面位于深绿工作区中央，按纸张比例显示。

#### 图片能力

- 点击选中；只有当前选中图片响应移动、缩放和旋转手势。
- 双指等比缩放，最大范围为页面可用区域；不得拉伸变形。
- 双指自由旋转时，图片元素框与内容共同绕元素中心旋转。
- Fit 默认完整显示图片；Fill/Crop 才允许裁切，并明确显示裁切状态。
- 支持替换、删除、裁切、前移、后移、置顶、置底和锁定。
- 图片选中显示陶土橙边框；不使用难以点击的右下缩放点。

#### 文字能力

- 支持添加、选中、输入、移动、删除、锁定和层级。
- 支持连续字号调节、颜色、对齐和 8 个稳定字体 token：System、Rounded、System Serif、Iowan Old Style、Baskerville、Avenir Next、American Typewriter、Noteworthy；不支持导入任意字体文件。
- 选中框右下角显示旋转柄；按住围绕中心自由旋转。
- 打开文字属性面板不默认聚焦输入框；只有用户点击正文输入区才弹键盘。
- 字号、颜色、字体和旋转必须进入共享文档并一比一导出。

字体解析规则：每个 token 必须先解析成一个可由 UIKit 与 CoreText 同时重建的确定 PostScript 名，并把该 resolved font 写入同一份渲染计划。不得把 System Serif 静默替换为 Times New Roman，也不得在预览与 PDF 分别选择不同 fallback。任一表面无法用相同 PostScript 名重建时，Book Check 以“字体不可用”阻断导出。旧存档映射为：`editorial → System Serif`、`quietSans/cinema → Avenir Next`、`handwritten → Noteworthy`。

#### 通用规则

- 手势结束合并为一个 Undo 事务。
- 首次进行移动、缩放、旋转、裁切、层级或文字内容修改后，页面默认 `isLayoutLocked = true`。
- 自动保存；切后台立即保存。保存失败保留内存编辑并提示可重试，不退出页面。

### 12 Pages

页面管理器支持跳转、增加照片页/注记页、复制、允许删除的页面、拖动重排和锁定。

- 封面、目录和结尾是结构页，不可直接删除；用户可隐藏可选内容或更改版式。
- 页面缩略图显示当前页、高亮、已修改和锁定标记。
- 拖动只显示合法插入位置，不能跨越受保护章节边界时解释原因。

### 13 Photo Edit / Crop

裁切为沉浸模式：固定元素框，用户在容器内平移、缩放照片。`Cancel` 恢复进入前状态，`Done` 作为一条 Undo 记录。替换照片保留 frame、rotation 和 zIndex，裁切重置为安全 Fit。

### 14 Text Edit

属性面板包含文字输入、连续字号、字体、颜色、对齐、层级和删除。旋转仍在画布通过旋转柄完成。长文本溢出实时提示，Book Check 将无法导出的溢出列为阻断项。

文字换行与溢出必须由共享 CoreText 排版结果判定：只有完整 grapheme/glyph range 被同一 text rect 消费才算可容纳；不得用估算行数或额外容忍一行。编辑器、阅读预览和 PDF 复用相同 resolved font、字号、行高、字距、段距和矩形。

### 15 Page Layout

Layout 只改变当前页面，展示 3–5 个与当前照片数量和宽高比兼容的页面配方。每个候选展示：布局缩略图、适用照片、裁切保留率和 `Recommended` 原因。

应用布局时：

- 不删除照片；容纳不下时明确说明将移动多少照片到新页。
- 用户确认后原子应用，一次 Undo 恢复。
- 应用后页面被视为用户编辑并锁定。

### 16 Apply Style / Regenerate

#### 模板切换

提供两个互斥选项：

1. `Visual style only`：只更新 token，不移动任何元素。
2. `Rearrange unlocked pages`：根据新模板重新规划未锁页面。

确认前展示：将更新页数、锁定不变页数、新增/删除页数和代表性前后对比。整个操作可一次 Undo。

#### 重新生成

入口位于 Book Preview / More，默认仅重新生成 `needsReflow` 和未锁页面。用户若选择整书重新生成，必须二次确认并说明手动编辑可能被清除；系统先保存恢复快照。锁定页默认永远不参与重新生成，除非用户逐页解除锁定。

### 17 Book Check

Book Check 检查完整文档，与是否购买无关。

- 阻断：缺失照片、无可导出照片、文字溢出、字体不可用、无法满足安全裁切。
- 建议：疑似重复、低 PPI、主体靠近裁切边、连续页面节奏重复。
- 阻断问题必须修复才能进入购买/最终导出；建议可忽略但记录选择。
- “安全修复”只能调整未锁页面，必须先展示影响，不自动执行。
- 点击问题必须携带 `issueID/issueIndex/pageID/elementID` 进入对应页面和元素；修复后返回 Book Check 的原问题位置。建议的“忽略”须二次确认并显示风险，忽略状态持久化且可撤销；阻断项不提供忽略入口。

从 17 进入 11 后，任何保存都会产生新 revision 并使旧检查失效；离开 11 时必须自动重跑同纸型/同规则版本的 Book Check，不能直接恢复旧结果。复检后用稳定 locator `ruleID+pageID+elementID` 寻找同一问题：仍存在则定位新 issue；已消失则定位 `min(formerIssueIndex,lastIndex)` 的下一问题；无问题则显示通过态。页面或元素被删除时使用相同 fallback。

检查缓存键为 `documentRevisionID + PDFPageSize + bookCheckRulesVersion`。首发规则标识独立固定为 `bookCheckRulesVersion = 1`，不与 PRD 文档版本绑定：目标打印 PPI `<100` 为阻断、`100..<200` 为建议、`>=200` 通过；文字溢出使用共享 CoreText 完整 UTF-16/grapheme 消耗；同一 `nearDuplicateGroup` 出现多张且非用户强制保留为建议；同一页面配方连续超过 2 页为建议；存在主体元数据时主体安全区域保留率 `<85%` 为阻断、`85..<95%` 为建议，无主体元数据时不产生阻断；focal point 距可视裁切边 `<5%` 为建议。规则版本变化必须使旧检查结果失效。

### 18 Purchase

仅由 17 Book Check 的当前 revision 无阻断通过态进入；10 Book Preview 不得直接打开 Purchase。明确交付：完整无水印 PDF、当前全部章节、A4/US Letter、永久本地保存和可重复导出。取消、失败和恢复失败不丢草稿，并回到 17 的相同通过态；购买权益保留，但任何后续编辑或纸型变化仍须重新 Book Check。

价格只能显示 StoreKit 返回的本地化 `displayPrice`，不得写死美元价格。商品加载中显示不含金额的 loading；商品不可用、离线或加载失败时禁用购买按钮并提供重试与恢复购买，用户返回原 Book Check 通过态，并可继续返回样章编辑。

### 19 Final Preview & Export

进入条件：Book Check 无阻断，且已购买/恢复购买/Debug bypass。

- 完整无水印逐页预览，支持 A4/US Letter。
- 从 Book Preview 点击 `Customize/Edit` 进入当前逻辑页；保存或返回后恢复该逻辑页。Final Preview 返回编辑器后以 Final Preview 为返回目标；从 Book Check 修复进入编辑器时优先恢复原 issue 与滚动位置。
- PDF 必须与该纸张尺寸预览使用同一个 document revision 和 resolved pages。
- 导出开始后显示真实页数进度；取消不删除草稿。
- 失败不暴露半成品文件；重试使用相同 revision，除非用户返回编辑。
- 成功后保存到 App 持久 `Exports` 目录，并通过 Share Sheet 保存或发送。

从 19 进入 11 后，保存产生新 revision，离开编辑器时自动重跑当前纸型 Book Check：出现 blocking 则进入 17；无 blocking 才返回 19。原 logicalPageID 仍存在则恢复该页；已被 reflow 删除则按 formerPageIndex 取最近存续页，整书重建且无对应页时回第 1 页。该自动复检完成前不得显示旧 Final Preview。

切换纸型会先创建新的 document revision、重新 resolve 全部页面并自动运行 Book Check；存在阻断时回到 17 并定位问题，不得继续导出。通过后 19 才显示新纸型。导出成功及 Share Sheet 关闭后停留在 19，显示持久文件与 `View in Archive`；用户点击 `Done/View in Archive` 才进入 20。

### 20 Archive

档案卡展示封面、模板、页数、草稿保存时间、最近导出和状态。

- 主按钮按 3.2 的 checkpoint 打开精确 resumeRoute；完整文档状态显示 `Continue editing`。
- `Open last PDF` 打开最近成功导出；文件丢失时提供重新导出。
- `Refresh new photos` 仅处理新照片，不覆盖原确认结果和编辑文档。
- 删除档案二次确认，删除本地索引关联、文档、缩略图和导出 PDF，不影响系统照片和购买权益。

## 5. 自动生成规则

### 5.1 照片编辑画像

每张确认照片产生本地 `EditorialProfile`：时间、地点（授权时）、宽高比、像素、主体安全区域、质量、近重复组、事件组和角色分。角色包括 `hero/supporting/sequence/detail/duplicate/lowQuality`。

### 5.2 事件与章节

- 优先按日期间隔归组；地点和视觉近似仅作为辅助。
- 章节保证跨年份和成长变化，不能只选最清晰时期。
- 相同连拍和近重复默认降权，但用户可人工加入。
- 素材不足则减少章节和页数，不复制照片填充。

### 5.3 页面配方与整书节奏

页面配方至少包括：Single Hero、Hero + Two Details、Diptych、Sequence、2×2、Quiet Note、Chapter Opener、Full Bleed。选择依据：角色、宽高比、主体安全、质量、时间顺序、模板适配和相邻页面节奏。

章节节奏遵循 `opener → hero → sequence → quiet/transition`，同一配方默认不得连续超过 2 页。

## 6. 模板和编辑保护

- 模板是规则集，不是静态图片。
- 用户修改过的页面默认锁定；标题文字修改也锁定该页面，但不锁定整个章节。
- Visual-only 不改变 frame、crop、rotation、zIndex 和分页。
- Rearrange 只作用未锁页面并产生可预览 diff。
- 自动布局、模板切换和重新生成均必须可撤销。

## 7. 数据与迁移

### 7.1 共享文档

唯一模型为 `MemoryBookDocument → MemoryBookPage → MemoryBookElement`。元素保存归一化 frame、rotation、zIndex、锁定、样式覆盖；图片保存 asset ID、Fit/Fill、cropScale/cropOffset/focalPoint；文字保存内容来源、字体、连续字号、颜色和对齐。

### 7.2 v1 草稿迁移

- 首次打开旧档案时创建 v2 文档副本，不原地覆盖旧数据。
- v1 Chapter 标题、说明、封面和照片顺序迁移到 Story Plan。
- 原有页面布局可映射时标记为锁定页面；无法映射时使用 Warm Paper 安全配方并记录迁移提示。
- 迁移失败保留旧档案可读和旧 PDF 导出能力，不允许清空草稿。
- 用户确认 v2 文档可正常打开并保存后，再标记迁移完成；旧数据至少保留一个版本周期。

## 8. 状态、恢复与降级

- 文档状态：`notGenerated/generating/ready/editing/needsCheck/checked/exporting/exported/recoveryRequired`。
- 进程终止、锁屏、切后台、低电量或热状态：保存最后成功事务；恢复时不自动重排。
- Smart Draft 失败：允许重试或使用简单时间线降级。
- 缩略图失败：显示占位并重试，不把占位当原图导出。
- PhotoKit asset 缺失：Book Check 阻断并提供替换。
- StoreKit 无网：允许继续编辑和样章预览；购买/恢复提示联网后重试。
- PDF 失败：删除临时文件，保留草稿和纸张选择。
- Smart Draft 的 `Cancel` 停止并丢弃本次未完成计算，回 06，保留最近成功 StoryPlanDraft；`Continue later` 保存步骤游标并进入 20，恢复时从最近完整步骤继续，不重新扫描。
- Debug bypass 仅允许在 `#if DEBUG` 且显式 UI test launch argument 下编译/触发；Release、TestFlight、App Store 构建中入口和分支均不可达，并由 Release 配置测试验证。

## 9. 隐私与情绪安全

- 所有扫描、事件归并、排版和 PDF 在本机执行。
- 不注册通知，不主动唤起照片，不根据离世时间营销。
- 敏感与 neverUse 规则在生成器、编辑候选、预览和 PDF 四层过滤。
- 本地匿名事件不得包含照片、宠物名、位置、用户文字或敏感阶段。

## 10. 成功与验收标准

| 维度 | 验收标准 |
| --- | --- |
| 主流程 | 新用户可从授权完成自动初稿、编辑、样章、购买和 PDF |
| 自动质量 | 20 本黄金样例中 ≥70% 初稿无需结构重做即可进入微调 |
| 模板差异 | 灰度盲测五模板识别准确率 ≥80% |
| 编辑完整性 | 本 PRD 图片、文字、页面、层级、锁定、Undo 全部可用 |
| 编辑保护 | 模板重排和重新生成对锁定页零变化 |
| 双渲染 | SwiftUI 与 PDF 核心几何误差 ≤1 pt；裁切、旋转、层级、文字、分页一致 |
| 内容安全 | 未批准 sensitive、excluded、neverUse、hiddenPeriod 零泄漏；已批准 sensitive 仅按本档案用户选择使用 |
| 恢复 | 重启和失败不丢确认、章节、页面编辑和最近成功导出 |
| 离线 | 内购以外的生成、编辑、检查、预览和 PDF 离线可用 |

## 11. 发布门禁

1. PRD 与统一原型页面、状态和跳转逐项一致。
2. 五模板完整视觉规格与至少 6 类代表页完成。
3. 共享文档模型和 A4/Letter 双渲染黄金 fixture 通过。
4. 自由编辑器能力无回退。
5. Book Check、购买、恢复、导出、旧草稿迁移通过。
6. 真机大相册、热状态、后台、进程重启与 PhotoKit 权限变化通过。
