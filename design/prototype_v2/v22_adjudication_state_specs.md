# Tailor v2.2｜新增裁决状态设计规范

> 视觉源：`v22_adjudication_states.html`  
> PNG 总览：`v22-adjudication-overview.png`  
> 单屏：`v22_adjudication_states.html?screen=01` 至 `?screen=12`

本文件只补充 v2.2 冻结后新增的状态和反馈，不改变 `Tailor_v2_PRD.md`、20 页主流程或现有 `detailed_states.html` 的职责。

## 1. 缺口清单与状态索引

| 稿号 | 页面 | 原资产缺口 | 新状态必须表达 | 主操作 |
|---|---|---|---|---|
| 01 | 02 Privacy | denied 后的安全去向不可见 | 权限拒绝、Manual Import 不扫描全库、可返回设置 | Import photos manually |
| 02 | 04 Manual Import | 3–500 张和私有副本边界不可见 | 已选数、最小/上限、App 私有副本、直接进入 pending review | Review selected photos |
| 03 | 06 Review | sensitive 批准缺风险确认 | 预览、风险说明、selected + sensitiveApprovedAt、neverUse 不可覆盖 | Include this photo |
| 04 | 06 Review | 识别代际与 stale decision 不可见 | 参考照/狗猫变化、新 generation、旧人工判断只读且须复核 | Review stale choices |
| 05 | 09 Book Style | 纸型创建时点不可见 | US Letter 默认、A4 可选、模板+纸型共同创建 revision | Create first draft |
| 06 | 17 Book Check | 19 切纸型后的复检状态缺失 | 新 revision、纸型、真实检查进度、blocking 返回 17 | Review blocking issue |
| 07 | 17 Book Check | 编辑保存后的稳定 issue fallback 缺失 | 旧检查失效、rule/page/element locator、former index fallback | Continue review |
| 08 | 18 Purchase | 10→18 绕行风险 | 明示来自当前 revision 的 17 通过态；Cancel 只回同一 17 | Unlock complete book |
| 09 | 20 Archive | 八类 checkpoint 未形成可视资产 | 8 个阶段、动态 CTA、唯一 resumeRoute | Continue current step |
| 10 | 11→16→11 | 嵌套 ReturnContextStack 无反馈 | Style 临时帧、底层 19/17 上下文保留、Cancel/Apply 先回 11 | Apply and return |
| 11 | 11→Check→17/19 | 自动复检中间态不可见 | 新 revision、旧结果不可显示、blocking/通过两条明确去向 | 自动，无可绕过 CTA |
| 12 | 10 Book Preview | 单一时期 3 张与 6 页样章冲突 | 不虚构第二时期；封面/目录/献词/章节/照片/结尾 6 页 | Customize sample |

## 2. 共用视觉规则

- 基准画布：390×844pt，遵守 safe area；沿用暖白 `#F7F1E5`、深绿 `#123F35`、陶土 `#C65B3D`、鼠尾草 `#DCE5D2`。
- 主标题使用品牌 serif；状态与操作使用 SF Pro。错误使用克制砖红，检查中使用暖金，不使用系统大面积警告红。
- 页面底部操作区固定在安全区上方，但主体必须可滚动；信息不能被 CTA 覆盖。
- `selected / sensitive / neverUse / stale / blocking / passed` 不能只靠颜色，必须同时显示文字或图标。
- 状态稿中的 revision、paperSize、generation 和 checkpoint 是用户可理解的诊断信息，不展示内部 error code 或数据库键。

## 3. 状态合同

### 02 denied 与 04 Manual Import

- denied 页面不得继续展示“扫描相册”承诺；明确 PHPicker 只返回用户选择的项目。
- Manual Import 计数显示 `已选择 / 500`。少于 3 张时主按钮禁用；达到 3 张后可进入 06。
- 私有副本说明必须出现在主按钮之前：仅复制明确选择的原图；删除档案时删除；以后获得权限会尝试指纹映射并清理已映射副本。

### 06 sensitive 与 stale

- sensitive 详情 sheet 的批准是两步语义合一：用户明确选中入册，并记录批准时间；取消不改变原 decision。
- neverUse 不提供普通批准入口。
- stale 卡片说明“原选择仍保留作参考，但不会进入书中”；批量重审与逐张重审都可达。

### 09 / 17 / 19 纸型与复检

- 09 的纸型选择与模板选择处于同一确认页，默认 US Letter。
- 19 切纸型后先显示复检页；检查完成前不显示新纸型 Final Preview。
- blocking 出现时停留/进入 17 并定位问题；无 blocking 才进入 19。

### 18 Purchase

- 顶部显示 `BOOK CHECK PASSED`、当前 revision 和纸型，防止误以为可从样章直接购买。
- Cancel、失败、离线只返回 17 的同一通过态；不直接返回 10，也不绕过检查进入 19。

### 20 checkpoint

- 档案卡只显示一个当前阶段为主 CTA；其余七类用于本规范总览，不在真实单卡同时提供八个按钮。
- checkpoint 与文案映射固定：profile / reference / scan / review / smartDraft / storyPlan / stylePending / documentReady。
- 恢复数据失效时回退到最早需修复页面，并保留后续成功快照。

### ReturnContextStack 与自动复检

- 11 进入 16 时展示轻量来源提示，例如 `Style for page 12`；16 完成只弹出临时帧回 11。
- 11 的底层 root context（10/17/19）、logical page、former index、paper 和 issue locator 必须保持。
- 编辑保存产生新 revision 后，离开 11 先进入无旧内容的复检中间态；不得短暂闪现旧 17/19。
- 17 fallback：同 locator → former index 附近下一项 → pass summary。
- 19 fallback：blocking→17；通过→原 logicalPageID → formerPageIndex 最近页 → 第 1 页。

### 单一时期 6 页样章

- 固定六页：封面、目录、真实献词/注记、唯一真实章节开场、真实照片页、结尾。
- 不把同一时期拆成两个章节，不复制照片，不增加虚构日期/事件/感受。
- 页码轨道可展示整书结构，但未购买用户只可打开带水印样章页。

## 4. 设计门禁

1. 12 个状态均能通过 HTML 单屏 URL 打开，且总览 PNG 可供评审。
2. 任何 Purchase 原型不得出现 10→18 文案或返回 10 的操作。
3. 任何编辑复检原型不得展示旧 revision 的 pass 状态。
4. 单一时期样章不得出现第二个虚构章节。
5. 这些状态只补充设计输入；代码实现仍须通过 `QA-V2-005`、真机、StoreKit 沙盒和完整流程验证。
