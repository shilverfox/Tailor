# Tailor v2.2 冻结裁决测试增量

> 基线：`Tailor-v2.2-docfreeze-2026-07-21`  
> 文档目的：把 v2.2 新增产品裁决转成唯一 Given/When/Then 测试预期和进入门禁。  
> 当前状态：**仅定义，全部 NOT RUN；本文不代表任何实现测试已通过。**

## 1. 证据类型

| 代码 | 证据类型 | 最低产物 |
| --- | --- | --- |
| `AUTO-UNIT` | 模型/服务单元测试 | 测试名、输入 fixture、断言、xcresult |
| `AUTO-UI` | XCUITest 流程测试 | 测试名、关键页面截图/附件、xcresult |
| `AUTO-FILE` | 文件/数据库自动检查 | 持久化记录、目录清单、哈希或数据库断言 |
| `SNAPSHOT` | 确定性视觉/PDF 快照检查 | 固定 fixture、基准图或 PDF、像素/结构差异报告 |
| `DEVICE` | 真机 PhotoKit/生命周期/性能 | 设备与系统版本、权限状态、录屏/截图、设备日志 |
| `STOREKIT` | StoreKit Configuration 或沙盒 Apple ID | 商品环境、地区、transaction 状态、截图与 StoreKit 日志 |
| `RELEASE` | Release/TestFlight 构建隔离 | Release 编译结果、符号/入口不可达断言、安装运行证据 |

原则：`AUTO-*` 可阻断合并；标注 `DEVICE/STOREKIT/RELEASE` 的用例没有对应真实证据时，不得用 Mock 通过替代上线门禁。

## 2. Paper、revision 与 Book Check 缓存

### V22-PAPER-01｜首次文档默认 US Letter

- Priority：P0
- Given：StoryPlanDraft 已确认，尚无 MemoryBookDocument，09 未手动切纸型。
- When：选择模板并点击 Use template。
- Then：以 `StoryPlanDraft + style + US Letter` 原子创建一个 MemoryBookDocument；paperSize 写入新 revision；只产生一套文档并进入 10。
- Evidence：`AUTO-UNIT + AUTO-UI`
- Gate：文档创建、默认纸型、单文档断言全部通过。

### V22-PAPER-02｜首次选择 A4

- Priority：P0
- Given：同 V22-PAPER-01，用户在 09 显式选择 A4。
- When：Use template。
- Then：首个 document revision 的 paperSize 为 A4；Preview 使用 A4 比例；不得先建 Letter 再静默替换。
- Evidence：`AUTO-UNIT + AUTO-UI`

### V22-PAPER-03｜Book Check 缓存键严格命中

- Priority：P0
- Given：存在检查结果 `(revision=R1, paper=Letter, rulesVersion=1)`。
- When：再次检查完全相同三元组。
- Then：允许复用 R1 结果；结果显示对应 revision 和 Letter。
- Evidence：`AUTO-UNIT`

### V22-PAPER-04｜任一缓存键变化立即失效

- Priority：P0
- Given：存在 V22-PAPER-03 的通过结果。
- When：分别只改变 documentRevisionID、PDFPageSize、bookCheckRulesVersion。
- Then：三种情况都不得复用旧结果，状态进入待检查/检查中。
- Evidence：`AUTO-UNIT`

### V22-PAPER-05｜Final Preview 切纸型后重新检查

- Priority：P0
- Given：R1/Letter 已通过检查且用户已解锁，位于 19。
- When：切换为 A4。
- Then：创建 R2、重新 resolve A4 并自动运行 rulesVersion=1；完成前不显示旧 Final Preview；有 blocking→17，无 blocking→19/A4。
- Evidence：`AUTO-UNIT + AUTO-UI`

## 3. 03–09 Archive checkpoint 恢复

下表每行均采用相同 When：保存稍后继续或进程终止后，从 20 点击动态主按钮。

| ID | Priority | Given | Then | Evidence |
| --- | --- | --- | --- | --- |
| V22-CP-01 | P0 | profile 不完整 | 显示 Continue profile，恢复 03 已保存字段 | AUTO-UNIT + AUTO-UI |
| V22-CP-02 | P0 | profile 完成、参考素材不足 | 显示 Choose photos，恢复 04；已有有效槽位保留 | AUTO-UNIT + AUTO-UI + DEVICE |
| V22-CP-03 | P0 | 扫描未完成，有游标和 processed IDs | 显示 Resume scan，恢复 05 当前进度；不从 0 自动重扫 | AUTO-UNIT + AUTO-UI + DEVICE |
| V22-CP-04 | P0 | 扫描完成或仍有 pending/stale decision | 显示 Review photos，恢复 06 原筛选与 decision | AUTO-UNIT + AUTO-UI |
| V22-CP-05 | P0 | Smart Draft 暂停或失败 | 显示 Continue draft，恢复 07 最近完整步骤；不重新扫描 | AUTO-UNIT + AUTO-UI |
| V22-CP-06 | P0 | StoryPlanDraft 待确认 | 显示 Review story，恢复 08 draft | AUTO-UNIT + AUTO-UI |
| V22-CP-07 | P0 | Story 已确认但尚未创建文档 | 显示 Choose style，恢复 09 选择 | AUTO-UNIT + AUTO-UI |
| V22-CP-08 | P0 | MemoryBookDocument 已创建 | 显示 Continue editing，恢复 10 最近 logicalPage | AUTO-UNIT + AUTO-UI |

### V22-CP-09｜checkpoint 数据失效回退

- Priority：P0
- Given：较晚 checkpoint 存在，但其依赖的参考文件/PhotoKit asset/StoryPlanDraft 已失效。
- When：从 Archive 继续。
- Then：只回退到最早需要修复的页面；不清空仍有效的 profile、decision、document 快照或最近 PDF。
- Evidence：`AUTO-UNIT + AUTO-UI + DEVICE`

## 4. Denied Manual Import 与私有副本生命周期

### V22-MANUAL-01｜2 张不可继续

- Priority：P0
- Given：PhotoKit denied，已完成 03。
- When：04 Manual Import 只选 2 张。
- Then：Review selected photos 禁用；不进入 05/06；显示至少 3 张要求。
- Evidence：`AUTO-UI + DEVICE`

### V22-MANUAL-02｜3 张与 500 张边界

- Priority：P0
- Given：PhotoKit denied。
- When：分别选择 3 张和 500 张可读文件。
- Then：两者都可直接进入 06；每张以 pending decision 出现；不得进入 05 或创建全库索引。
- Evidence：`AUTO-UNIT + AUTO-UI + DEVICE`

### V22-MANUAL-03｜超过 500 张

- Priority：P0
- Given：已选择 500 张。
- When：尝试添加第 501 张。
- Then：不写入第 501 张并给出上限说明；已选 500 张及副本不丢失。
- Evidence：`AUTO-UI + DEVICE`

### V22-MANUAL-04｜私有副本创建范围

- Priority：P0
- Given：PhotoKit denied，用户选择 3 张，其中 1 张读取失败。
- When：导入完成。
- Then：只为成功且明确选择的 2 张创建 App 私有副本；失败项可移除/重选；不得复制未选择文件。
- Evidence：`AUTO-FILE + DEVICE`

### V22-MANUAL-05｜授权后指纹映射

- Priority：P0
- Given：manual asset 私有副本存在，随后用户授予 PhotoKit 权限。
- When：执行指纹映射。
- Then：成功匹配的项改为 PHAsset 引用并删除对应私有副本；未匹配项继续使用 manual asset，不丢 decision。
- Evidence：`AUTO-UNIT + AUTO-FILE + DEVICE`

### V22-MANUAL-06｜删除档案清理

- Priority：P0
- Given：档案含 manual asset 私有副本与已映射 PHAsset。
- When：二次确认删除档案。
- Then：删除该档案全部私有副本和索引关联，不删除系统照片，不删除全局购买权益。
- Evidence：`AUTO-FILE + DEVICE`

## 5. Match generation、species/reference 与 stale decision

### V22-MATCH-01｜embedding 键与宠物身份解耦

- Priority：P0
- Given：相同 assetID 与 featureExtractorVersion 已有 embedding。
- When：更改宠物姓名、年份、species 或参考照。
- Then：姓名/年份/species/参考照均不重复提取 embedding；只有 featureExtractorVersion 变化才建立新 embedding。
- Evidence：`AUTO-UNIT + AUTO-FILE`

### V22-MATCH-02｜姓名/年份不产生新 match generation

- Priority：P0
- Given：当前 generation 为 `hash(profileID+species+referenceSetFingerprint+matcherVersion)`。
- When：只改姓名或年份。
- Then：generationID、匹配结果和人工 decision 保持有效。
- Evidence：`AUTO-UNIT`

### V22-MATCH-03｜species/reference/matcher 任一变化产生新 generation

- Priority：P0
- Given：旧 generation G1 已完成并含人工 selected/excluded。
- When：分别改变 species、referenceSetFingerprint、matcherVersion。
- Then：每种情况生成不同 G2；复用已有 embedding 对授权范围全量重匹配，不能只处理新增照片。
- Evidence：`AUTO-UNIT + AUTO-FILE`

### V22-MATCH-04｜旧人工 decision 进入 stale

- Priority：P0
- Given：G1 有 selected、excluded、sensitiveApproved 照片。
- When：生成 G2。
- Then：G1 decision 只读保留为 staleDecision；在 G2 明确复核前均不计入 eligibility，不静默继承批准时间。
- Evidence：`AUTO-UNIT + AUTO-UI`

### V22-MATCH-05｜同 generation 只增量处理新增照片

- Priority：P1
- Given：generationID 不变且全量扫描成功，随后新增照片。
- When：Refresh new photos。
- Then：跳过已有 processed IDs，只索引/匹配新增照片；原 decision 和编辑文档不被覆盖。
- Evidence：`AUTO-UNIT + DEVICE`

## 6. Sensitive approval 与 neverUse

### V22-SAFE-01｜Normal selected

- Priority：P0
- Given：`sensitivity=normal`。
- When：decision 改为 selected。
- Then：若未 hiddenPeriod，则 eligibility=true。
- Evidence：`AUTO-UNIT`

### V22-SAFE-02｜Sensitive 未批准

- Priority：P0
- Given：`sensitivity=sensitive, sensitiveApprovedAt=nil`。
- When：即使通过批量操作尝试 selected。
- Then：不得入册；必须进入详情风险说明完成显式确认。
- Evidence：`AUTO-UNIT + AUTO-UI`

### V22-SAFE-03｜Sensitive 显式批准

- Priority：P0
- Given：用户在详情页看到风险说明。
- When：明确选择入册。
- Then：同一事务写入 `decision=selected + sensitiveApprovedAt`；eligibility=true；取消不得写批准时间。
- Evidence：`AUTO-UNIT + AUTO-UI`

### V22-SAFE-04｜NeverUse 不可覆盖

- Priority：P0
- Given：`sensitivity=neverUse`。
- When：逐张或批量尝试 selected/approve。
- Then：仍不可入册，不提供普通批准旁路。
- Evidence：`AUTO-UNIT + AUTO-UI`

### V22-SAFE-05｜四层零泄漏

- Priority：P0
- Given：混入未批准 sensitive、neverUse、hiddenPeriod、excluded 和 staleDecision。
- When：依次生成 draft、打开编辑候选、阅读 Preview、导出 PDF。
- Then：四层均零出现；只有 normal selected 或 approved sensitive selected 可见。
- Evidence：`AUTO-UNIT + AUTO-UI + AUTO-FILE`

## 7. ReturnContextStack、编辑复检与 fallback

### V22-RETURN-01｜10→11→16 嵌套返回

- Priority：P0
- Given：10 的 logicalPageID=P5 进入 11，再从 11 进入 16。
- When：16 Cancel 或 Apply。
- Then：只弹出 16 临时帧并回 11/P5；离开 11 后才消费底层帧回 10/P5。
- Evidence：`AUTO-UNIT + AUTO-UI`

### V22-RETURN-02｜17→11→16 嵌套返回

- Priority：P0
- Given：17 issue locator=`ruleID+pageID+elementID`、formerIssueIndex=I，进入 11，再进入 16。
- When：16 Cancel/Apply 后离开 11。
- Then：16 先回 11；若产生新 revision，先自动复检，绝不展示旧结果。
- Evidence：`AUTO-UNIT + AUTO-UI`

### V22-RETURN-03｜问题仍存在

- Priority：P0
- Given：由 17 issue 进入 11，保存后该稳定 locator 在新检查仍存在。
- When：自动复检完成。
- Then：17 定位新结果中的同一 locator，并恢复对应滚动位置。
- Evidence：`AUTO-UNIT + AUTO-UI`

### V22-RETURN-04｜问题消失或页面/元素删除

- Priority：P0
- Given：formerIssueIndex=I，编辑后旧 locator 消失或 page/element 被删除。
- When：自动复检完成。
- Then：定位 `min(I,lastIndex)` 附近下一问题；无问题则显示 pass summary；不得引用旧 issue 对象。
- Evidence：`AUTO-UNIT + AUTO-UI`

### V22-RETURN-05｜19→11 后出现 blocking

- Priority：P0
- Given：19/P5 进入 11，编辑产生新 revision 和 blocking。
- When：离开 11 并完成自动复检。
- Then：进入 17 定位 blocking；不得返回或短暂显示旧 19。
- Evidence：`AUTO-UNIT + AUTO-UI`

### V22-RETURN-06｜19→11 通过及页面 fallback

- Priority：P0
- Given：19/P5、formerPageIndex=4 进入 11。
- When：保存后自动检查无 blocking。
- Then：P5 存在则回 19/P5；P5 被 reflow 删除则回 index 4 最近存续页；无对应页时回第 1 页。
- Evidence：`AUTO-UNIT + AUTO-UI`

## 8. 唯一付费链 10→17→18→19

### V22-PAY-01｜10 不可直达 18

- Priority：P0
- Given：未购买用户位于 10。
- When：尝试打开完整预览或导出。
- Then：先进入 17；不存在直接展示 Purchase 的导航、deeplink 或按钮旁路。
- Evidence：`AUTO-UNIT + AUTO-UI`

### V22-PAY-02｜Blocking 不可购买

- Priority：P0
- Given：当前 revision 的 17 存在 blocking。
- When：用户查看检查结果。
- Then：18 不可进入，必须先修复 blocking。
- Evidence：`AUTO-UNIT + AUTO-UI`

### V22-PAY-03｜当前 revision 通过后进入 Purchase

- Priority：P0
- Given：当前 revision+paper+rulesVersion 已通过，用户未购买。
- When：17 Continue。
- Then：进入 18；Purchase context 绑定该检查通过态。
- Evidence：`AUTO-UNIT + AUTO-UI`

### V22-PAY-04｜取消/失败/恢复失败

- Priority：P0
- Given：从 V22-PAY-03 进入 18。
- When：分别取消购买、购买失败、恢复失败或离线。
- Then：回 17 相同通过态和滚动位置；草稿与编辑不丢；失败不授予权益。
- Evidence：`AUTO-UI + STOREKIT`

### V22-PAY-05｜购买/恢复成功

- Priority：P0
- Given：从当前 revision 的 17 通过态进入 18。
- When：购买或恢复成功。
- Then：授予非消耗型权益并进入 19 同 revision/paper；不得重新生成文档。
- Evidence：`AUTO-UNIT + AUTO-UI + STOREKIT`

### V22-PAY-06｜购买后修改仍重检

- Priority：P0
- Given：已购买并位于 19。
- When：编辑或切换纸型产生新 revision。
- Then：权益保留，但新 revision 必须按 V22-PAPER-05/V22-RETURN-05/06 重检。
- Evidence：`AUTO-UNIT + AUTO-UI + STOREKIT`

## 9. 单时段最小样章

### V22-SAMPLE-01｜3 张同一时段

- Priority：P0
- Given：仅 3 张 eligible 照片，均属于同一真实时期。
- When：生成 Book Preview 样章。
- Then：不得虚构第二时期或复制照片；生成至少 6 页真实结构，包含封面、目录、一个真实章节开场、真实照片页、结尾，并以用户真实献词/注记页补足结构；样章页数=`min(8,totalPageCount)`。
- Evidence：`AUTO-UNIT + AUTO-UI + SNAPSHOT`

### V22-SAMPLE-02｜存在两个及以上真实时期

- Priority：P1
- Given：eligible 素材包含至少两个真实时期，整书≥8页。
- When：生成样章。
- Then：样章为 8 页，优先包含两个不同时段章节页；不复制照片、不虚构标题。
- Evidence：`AUTO-UNIT + AUTO-UI + SNAPSHOT`

## 10. Debug bypass Release 隔离

### V22-DEBUG-01｜Debug 必须显式参数

- Priority：P0
- Given：DEBUG 构建未传 UI-test bypass 参数。
- When：未购买且尝试进入 19。
- Then：不得 bypass，仍走 10→17→18。
- Evidence：`AUTO-UNIT + AUTO-UI`

### V22-DEBUG-02｜UI-test Debug bypass

- Priority：P1
- Given：DEBUG 构建且传入唯一显式 UI-test launch argument。
- When：测试进入 19。
- Then：仅测试环境可 bypass；页面/导出仍要求当前 revision Book Check 无 blocking。
- Evidence：`AUTO-UI`

### V22-DEBUG-03｜Release/TestFlight/App Store 不可达

- Priority：P0 Release Gate
- Given：Release 配置构建。
- When：静态检查、安装运行并尝试所有入口/deeplink/launch arguments。
- Then：bypass 入口、分支和可触发参数均不可达；未购买不能进入 19 或导出。
- Evidence：`RELEASE + AUTO-UI`

## 11. Book Check rulesVersion = 1

### V22-RULES-01｜首发规则版本独立固定

- Priority：P0
- Given：PRD/应用版本任意变化，但 Book Check 规则未升级。
- When：创建检查请求与持久化结果。
- Then：`bookCheckRulesVersion == 1`，不得使用 `2.2`、build number 或 PRD 版本替代。
- Evidence：`AUTO-UNIT + AUTO-FILE`

### V22-RULES-02｜version 变化失效旧缓存

- Priority：P0
- Given：R1/paper/rulesVersion=1 已有结果。
- When：显式把规则版本升级为 2 的 fixture 运行。
- Then：旧结果失效并完整重检；新结果保存 rulesVersion=2；document 内容不因检查本身改变。
- Evidence：`AUTO-UNIT`

### V22-RULES-03｜版本 1 阈值边界

- Priority：P0
- Given：构造 PPI 99/100/199/200，subject retention 84.99%/85%/94.99%/95%，focal distance 4.99%/5%，重复组和连续 2/3 页同配方 fixture。
- When：rulesVersion=1 执行 Book Check。
- Then：严格得到 PRD 冻结的 blocking/suggestion/pass 边界；无主体元数据不得产生主体裁切 blocking。
- Evidence：`AUTO-UNIT`

## 12. v2.2 增量门禁

| Gate | 进入条件 | 必须证据 | 状态 |
| --- | --- | --- | --- |
| V22-GATE-DOC | PRD/原型可测试性 | 冻结审计 P0=0/P1=0、8 SHA 匹配 | 已由文档审计完成 |
| V22-GATE-MODEL | 进入 UI 提测 | 本文所有 P0 `AUTO-UNIT/AUTO-FILE` 通过 | NOT RUN |
| V22-GATE-UI | 进入真机验收 | 本文所有 P0 `AUTO-UI` 通过并有 xcresult/关键截图 | NOT RUN |
| V22-GATE-DEVICE | 签署照片与恢复链 | CP、Manual Import、增量扫描的 DEVICE 用例通过 | NOT RUN |
| V22-GATE-STOREKIT | 签署付费链 | PAY-04/05/06 在 StoreKit 沙盒通过 | NOT RUN |
| V22-GATE-RELEASE | 提交 TestFlight/App Store 前 | DEBUG-03 Release 构建与运行不可达证据 | NOT RUN |
| V22-GATE-REGRESSION | 最终发布候选 | 既有 v2 用例 + 本增量全部通过，且 QA-V2-005 等实施门禁另行关闭 | NOT RUN |

阻断规则：

1. 任一 P0 用例失败，不得进入下一证据层。
2. Mock StoreKit 只能关闭 `AUTO-UNIT/AUTO-UI`，不能关闭 `STOREKIT`。
3. Simulator PhotoKit 不能替代 `DEVICE` 的权限变化、进程恢复和私有副本生命周期证据。
4. 文档 PASS 不替代代码、像素、真机、性能、StoreKit 或内容质量门禁。
