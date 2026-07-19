# Tailor v1 真机放行验收脚本与证据记录表

**用途：** 在取得测试 iPhone、经授权的测试相册、StoreKit Sandbox 帐号后，按本脚本一次性收集发布放行证据。  
**范围：** 真实照片扫描与校准、长相册/中断/增量、StoreKit 购买、以及 Warm Paper / Quiet Night / Field Notes × A4 / US Letter 的逐页预览与 PDF 核验。  
**边界：** 不使用真实用户的离世宠物资料；不上传照片、宠物名、日期、地点、章节文字或特征向量；所有屏幕录制和导出 PDF 均作为受控测试资料保存。

---

## 0. 放行规则与执行产物

### 0.1 总放行规则

| 门禁 | 通过条件 | 证据 |
| --- | --- | --- |
| R0 构建 | Release Candidate 可在所有目标真机安装并启动 | Xcode 安装日志、App 版本/构建号截图 |
| R1 识别安全 | 标注集指标达到产品批准阈值；所有高置信自动选中至少有两张参考照一致支持 | 标注清单、`ScanAuditMetrics`、校准表、Review 截图 |
| R2 韧性 | 长相册、后台、锁屏、低电、重启、增量重扫不丢失 checkpoint 或人工决定 | 步骤录像、前后截图、checkpoint/metrics 记录 |
| R3 商业闭环 | Sandbox success/cancel/fail/restore 均符合状态保留和权益语义 | StoreKit 截图、交易记录、恢复结果 |
| R4 成品保真 | 3 个 v1 模板 × 2 种纸张的预览/PDF 逐页核验均通过 | 每个组合的预览截图、PDF、逐页记录表 |
| R5 隐私 | 飞行模式下可完成已授权素材流程；删除档案后 Tailor 数据不可恢复且系统照片、购买权益不受影响 | 录屏、设置截图、删除前后检查 |

**判定：** 任意 P0 失败为 `BLOCKED`；所有 P0 通过、P1 已登记且有 owner/计划，方可标记 `RELEASE CANDIDATE ACCEPTED`。

### 0.2 本轮交付目录（建议）

```text
Tailor-Device-Acceptance-YYYYMMDD/
  00-environment.md
  01-consent-and-photo-fixtures.md
  02-scan-calibration.csv
  03-scan-resilience.md
  04-storekit-sandbox.md
  05-pdf-page-verification/
    warm-paper-a4/
    warm-paper-letter/
    quiet-night-a4/
    quiet-night-letter/
    field-notes-a4/
    field-notes-letter/
  06-delete-privacy.md
  final-signoff.md
```

命名截图/录屏：`<case-id>_<device>_<step>_<PASS|FAIL>.png|mov`；PDF：`<template>_<paper>_<build>.pdf`。不要把用户姓名、宠物名或 `PHAsset.localIdentifier` 写入汇总报告。

---

## 1. 先决条件与环境记录

### 1.1 必须具备

- [ ] iPhone（最低 iOS 17）和当前发布系统 iPhone 各一台；记录型号、系统、可用空间、电池健康度。
- [ ] 最新 Release Candidate，关闭 Debug purchase bypass；记录 bundle ID、构建号、git commit/CI artifact。
- [ ] 一个完整照片权限测试库：至少 1,000 张；推荐另准备 10,000 张压力库。
- [ ] 一个受限权限库、一个拒绝权限库、至少一张 iCloud 未下载原图样本。
- [ ] 至少三张同一宠物的参考图，覆盖年龄、角度、光照；另备两张/失效 reference 反例。
- [ ] 已签署同意的标注集：目标宠物、同品种其他宠物、其他动物（含猴子/小熊猫）、人像、玩偶、空景、连拍、重复导入、幼年/老年、低光/背光、无日期照片。
- [ ] StoreKit Sandbox tester、App Store Connect 中已配置的非消耗型商品 `tailor.life_archive.unlock`，以及可模拟取消/失败的测试条件。
- [ ] 文件 App、可查看 PDF 的阅读器、屏幕录制；可选：macOS Preview/Acrobat 作纸张尺寸与逐页比对。

### 1.2 `ScanAuditMetrics` 先决条件

本轮实装的 checkpoint 已提供本地聚合 `ScanAuditMetrics`。验收人员应从 Debug diagnostics、开发导出的匿名测试日志或工程师提供的只读诊断屏读取它；**不得**为验收临时上传或导出照片/资产标识符。

| 字段 | 验收解释 | 预期观察 |
| --- | --- | --- |
| `processed` | 已处理资产数 | 最终等于当前授权范围内应扫描资产数（不含明确排除的参考照时须记录规则）。 |
| `referenceFailures` | 参考照读取/特征失败 | 正常基准为 0；失效 reference 用例 >0 或明确报 `insufficientReferences`。 |
| `imageUnavailable` | 资源不可读取 | iCloud/权限/资源异常时增加；不得抹掉既有 checkpoint。 |
| `animalVisionFailures` | 动物 Vision 调用失败 | 正常基准应为 0；非 0 要保留错误证据。 |
| `speciesRejected` / `identityRejected` | 物种/身份阈值拒绝数 | 干扰样本应主要落入此处，而不是进入自动选中。 |
| `candidates` / `needsReview` / `autoSelected` | 候选分桶 | `autoSelected <= candidates`；低置信目标宠物应能在 `needsReview` 人工处理。 |
| `duplicateGrouped` / `duplicateSuppressed` | 连拍/重复导入策略 | 未决定重复图应分组可见；已人工决定的历史项不应被改写。 |
| `lowPower` / `thermal` / `interrupted` | 中断原因 | 对应注入用例至少各验证一次（设备不支持热状态注入时记为受控未执行）。 |

**开始前记录表：**

| 字段 | 值 |
| --- | --- |
| 执行日期 / 时区 |  |
| 执行人 / 复核人 |  |
| App 版本 / Build / commit |  |
| 设备型号 / iOS / 可用空间 |  |
| 权限状态 | 完整 / 受限 / 拒绝 |
| 网络 | Wi‑Fi / 蜂窝 / 飞行模式 |
| StoreKit 环境 / 测试帐号别名 |  |
| 测试相册规模 / 标注目标宠物数 |  |
| 参考图数 / 物种 |  |

---

## 2. 真实相册标注校准（R1）

### 2.1 标注集准备

为每个测试资产在受控本地表登记一个匿名 fixture 编号（例如 `D001`），**不要**把 `localIdentifier` 放入放行报告。标注字段：

| Fixture | 类别 | 是否目标宠物 | 应有分桶 | 实际分桶 | 人工决定 | 备注 |
| --- | --- | ---:| --- | --- | --- | --- |
| D001 | 目标宠物、幼年 | 是 | selected 或 needs review |  |  |  |
| D002 | 同品种另一只狗 | 否 | rejected / needs review，绝不高置信自动选中 |  |  |  |
| D003 | 猴子/小熊猫 | 否 | rejected |  |  |  |
| D004 | 人像/玩偶/空景 | 否 | rejected |  |  |  |
| D005 | 连拍/重复导入 | 是 | 分组且可人工处理 |  |  |  |

最小建议样本：目标宠物 ≥50 张、干扰 ≥100 张、同品种其他宠物 ≥20 张、重复/连拍 ≥20 张；样本不足时只可形成探索性报告，不能调整正式阈值或宣称识别已校准。

### 2.2 执行脚本

1. 清空测试档案，不删除系统测试照片；冷启动，授予完整照片权限。
2. 建立档案并选择 **3–5 张** reference。记录 reference 的年龄/角度覆盖。
3. 反例：只选 2 张、重复选择、撤回一张已选 reference 或用受限权限使 reference 不可用。预期：不得开始扫描，明确提示重新选择；记录 `referenceFailures` 或 `insufficientReferences`。
4. 正例：恢复至少 3 张有效 reference 后开始扫描。录制从 0% 到完成的首尾；保存最终 `ScanAuditMetrics`。
5. 在 Review 中分别检查 High / Needs Review / Excluded；按 fixture 标注实际分桶。
6. 对 Needs Review 的真实目标宠物批量 `Add to archive`；对错误候选执行 `Not this pet`。确认“非目标物种和人像不自动选中”。
7. 逐项计算下表指标；附 `ScanAuditMetrics` 截图/文本和 Review 截图。

### 2.3 校准结果与签收表

| 指标 | 公式 | 本次值 | 批准阈值 | PASS/FAIL |
| --- | --- | ---:| ---:| --- |
| Candidate precision | 真实目标候选 / 全部候选 |  |  |  |
| Candidate recall | 已进入候选的真实目标 / 全部标注目标 |  |  |  |
| High-auto false positive rate | 错误自动选中 / 全部自动选中 |  |  |  |
| Needs-review recall | Needs Review 中真实目标 / 全部标注目标 |  |  |  |
| 同品种其他宠物高自动选中数 | 计数 |  | 0 |  |
| 猴子/小熊猫/人像高自动选中数 | 计数 |  | 0 |  |
| 重复图误抑制数 | 人工认为应可见而不可见的数 |  | 0 |  |

**人工签收：** 产品 ___  测试 ___  识别负责人 ___  日期 ___

---

## 3. 长相册、后台、低电、重启与增量（R2）

每个步骤均记录：开始/结束时间、已处理数、候选数、`ScanAuditMetrics`、截图/视频路径、结果。

| ID | 条件与操作 | 必验结果 | 记录 |
| --- | --- | --- | --- |
| S-01 长相册 | 在 ≥1,000 张（推荐 10,000 张）库开始扫描 | 进度单调更新，UI 无假死；可暂停/恢复；无崩溃。 | `processed`、耗时、峰值电量/温度主观观察 |
| S-02 后台/锁屏 | 扫描中切后台、锁屏 ≥30 秒，再返回 | 已确认/已处理结果保留；只在用户明确继续后恢复；不发送通知。 | 前后 checkpoint |
| S-03 强制终止/重启 | 扫描中从 App 切换器终止或重启设备后重新打开 | 同一 catalog 从 checkpoint 继续；候选及人工决定不清空。 | `nextAssetIndex`、fingerprint、候选数 |
| S-04 同数量库变更 | 中断后删除一张并添加一张，使资产数不变，再继续 | fingerprint 不同，安全从 0 重新扫描；仍存在候选保留，已删资产不保留。 | 变更前后 fingerprint、候选清单计数 |
| S-05 低电 | 打开 iOS 低电量模式后启动/继续扫描 | 明确提示暂停原因；checkpoint 留存；关闭低电后用户手动继续。 | `lowPower` 增量 |
| S-06 热状态 | 使用受控设备实验室工具触发 serious/critical thermal；若无法安全注入，标记 N/A 并附设备限制 | 明确提示冷却后继续；checkpoint 留存。 | `thermal` 增量或 N/A 依据 |
| S-07 增量重扫 | 完成扫描与人工 Review 后，新加入目标宠物图、干扰图和重复导入图；从档案点 `Rescan for new photos` | 已有 selected/excluded 不被改写；章节、MemoryBook、PDF records 保留；仅新候选加入。 | 重扫前后状态截图 |
| S-08 删除索引 | 有已扫档案与导出 PDF 时执行删除档案、重启 App、重新建同名档案 | Tailor 的匹配/编辑/PDF 不可恢复；系统照片与购买权益不受影响。 | 删除确认、Files、重启后截图 |

---

## 4. StoreKit Sandbox 放行脚本（R3）

每次先完成一个可编辑相册，至少包含两个年份章节和可导出的真实测试照片。购买测试不得依赖 Debug bypass。

| ID | 场景 | 操作 | 期望 | PASS/FAIL / 证据 |
| --- | --- | --- | --- | --- |
| K-01 Success | 在 Sandbox 登录可购买帐号，点击解锁并完成 Apple sheet | 解锁完整无水印预览/PDF；`tailor.life_archive.unlock` 持久；编辑状态未丢。 |  |
| K-02 Cancel | 在 Apple sheet 点击取消 | 留在可编辑/可预览状态；不产生无水印 PDF；无情绪施压文案。 |  |
| K-03 Fail | 使用 StoreKit Test 失败交易或可控网络/帐号错误 | 显示可理解的重试提示；章节、样式、纸张、编辑不变；不重复扣费。 |  |
| K-04 Restore success | 在已购 Sandbox 帐号或重装 App 后点 Restore Purchases | 恢复无水印导出资格；不要求重新购买；档案/本地 PDF 恢复按产品存储边界验证。 |  |
| K-05 Restore no entitlement | 使用未购 Sandbox 帐号点恢复 | 明确无可恢复权益；仍可编辑和看水印样章。 |  |
| K-06 Persistence | 成功购买后杀 App、重启、切换网络 | 权益仍存在；无网络时可导出已在本地的档案。 |  |

记录：StoreKit 配置版本 ___；商品 ID ___；测试帐号别名 ___；交易截图/日志路径 ___。

---

## 5. 三模板 × 双纸张逐页预览/PDF 核验（R4）

本 v1 放行矩阵依据 PRD 的三个模板：**Warm Paper、Quiet Night、Field Notes**。每个组合必须使用同一份已确认、跨至少两个时期的测试档案；修改后的照片位置、裁剪、文字与封面必须先保存再验证。

### 5.1 执行步骤（每个组合重复）

1. 在编辑器确认至少包含：封面、献词、目录、两个章节开场、单图/双图/拼贴照片页、结尾；如内容多于 6 张，验证自动分页。
2. 进行代表性编辑：替换一张图、拖动/缩放/裁剪一张图、编辑标题/日期/备注、调整照片顺序；退出并重新进入，确认持久化。
3. 选择模板与纸张；在全册 SwiftUI 预览按页截图，写下总页数和每页 page kind。
4. 已购 Sandbox 状态下导出无水印 PDF；保存至 Files，再用同一设备和桌面阅读器逐页打开。
5. 对照下表逐页核验；任何位置、图层、裁剪、文字、页序、模板、纸张不一致均为 FAIL。

### 5.2 组合记录表

| 模板 | A4 预览/PDF | US Letter 预览/PDF | 执行人 | 复核人 | 结论 |
| --- | --- | --- | --- | --- | --- |
| Warm Paper | 文件/录屏： | 文件/录屏： |  |  |  |
| Quiet Night | 文件/录屏： | 文件/录屏： |  |  |  |
| Field Notes | 文件/录屏： | 文件/录屏： |  |  |  |

### 5.3 每个组合的逐页核验表

| 页码 | page kind | 预览截图 | PDF 页 | 内容/裁剪/文字一致 | 模板与颜色正确 | 水印状态正确 | 背景/图层/页序正确 | PASS/FAIL |
| ---:| --- | --- | ---:| --- | --- | --- | --- | --- |
| 1 | Cover |  | 1 |  |  | 已购无水印 |  |  |
| 2 | Dedication |  | 2 |  |  | 已购无水印 |  |  |
| 3 | Contents |  | 3 |  |  | 已购无水印 |  |  |
| 4…n | Chapter opener / photo selection / milestone |  |  |  |  | 已购无水印 |  |  |
| Last | Closing |  |  |  |  | 已购无水印 |  |  |

**必须额外核验：**

- [ ] A4 与 US Letter 的页面尺寸正确，预览与 PDF 的归一化布局一致。
- [ ] 无黑页、透明页、空白异常页、重复页、图层反转或裁剪露白。
- [ ] selected 以外、敏感、hidden、never-use 照片不进入预览/PDF。
- [ ] 未购买水印样章为 6–8 页且每页清晰水印；已购买完整 PDF 无水印。
- [ ] 文件写入后可从档案重新访问、可 Share Sheet 分享；取消分享不会删除文件。

---

## 6. 最终签署

| 门禁 | 结果 | P0 缺陷/例外 | 证据路径 | 签署 |
| --- | --- | --- | --- | --- |
| R0 构建 |  |  |  |  |
| R1 识别标注校准 |  |  |  |  |
| R2 韧性与增量 |  |  |  |  |
| R3 StoreKit Sandbox |  |  |  |  |
| R4 模板/PDF 逐页保真 |  |  |  |  |
| R5 隐私/删除 |  |  |  |  |

**最终结论：** `ACCEPTED / BLOCKED / ACCEPTED WITH P1 EXCEPTIONS`  
产品 ___　设计 ___　研发 ___　测试 ___　日期 ___

## 7. 不能由本脚本替代的证明

- 真正的量产识别阈值必须基于规模足够、经同意且有标注的多设备数据集；一次真机验收不能证明跨品种、年龄、光照的普适准确率。
- iOS thermal state 在普通人工测试中未必可安全、稳定触发；没有受控实验室条件时应标为 N/A，不能伪造 PASS。
- StoreKit Sandbox 通过不等价于 App Store 审核、地区定价、税务、家庭共享及真实生产交易均已通过。
- PDF 的肉眼逐页核验是发布门禁；若要求像素级结论，还需冻结设计基线、定义截图/渲染差异阈值并保留对比产物。
