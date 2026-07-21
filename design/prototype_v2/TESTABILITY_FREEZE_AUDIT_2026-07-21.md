# Tailor v2 PRD / 原型可测试性冻结审计

- 审计日期：2026-07-21
- 审计范围：`Tailor_v2_PRD.md`、`prototype_map.html`、`flow_and_screen_contract.md`、`state_matrix.md`、`v2_pages_01_06_contract.md`、`prd_prototype_traceability.md`、`PRD_PROTOTYPE_FREEZE_2026-07-21.md`；并读取冻结单列为关键状态基线的 `detailed_state_specs.md`。
- 审计目的：确认进入条件、产物、状态、恢复、付费、错误与验收口径是否能形成唯一测试预期。
- 限制：只审文档，不审代码，不修改 PRD、原型合同或业务实现。

## 1. 总结论

**FAIL。当前不能签署“产品与原型输入不存在 P0 需求歧义”，不应继续新的实现范围。**

冻结清单中 7 个文件及 `detailed_state_specs.md` 的当前 SHA-256 与冻结单完全一致，说明文件没有发生未登记漂移。`07 → 08 → 09` 的首次产物时点也已一致：07 只生成 `StoryPlanDraft`，08 确认/编辑该 draft，09 才原子创建 `MemoryBookDocument`。

但是端到端仍存在 5 个 P0 和 8 个 P1 可测试性缺口。P0 会让相同输入产生两种合理实现或测试预期，必须先由产品/设计明确裁决并同步更新全部冻结文档。

## 2. 已通过项目

| 项目 | 结论 | 证据 |
| --- | --- | --- |
| 冻结文件完整性 | PASS | 7 个冻结文件及 detailed state spec 的 SHA-256 与冻结确认单一致。 |
| 07 Smart Draft 产物 | PASS | PRD 107、129；Flow 39；Traceability 35：只持久化 `StoryPlanDraft`，不创建页面。 |
| 08 Story Plan 首次职责 | PASS（有 P1 文案缺口） | PRD 129、Flow 40、Traceability 35：首次只编辑/确认 StoryPlanDraft。 |
| 09 首次文档创建时点 | PASS（纸型来源 P0 未决） | PRD 143、Flow 41、State Matrix Book Style、Traceability 35：首次模板确认后原子创建完整文档。 |
| 未购买编辑权 | PASS | PRD 24–27、153；Flow 65：可完整编辑，只限制完整无水印预览和导出。 |
| StoreKit 价格与失败基本规则 | PASS | PRD 244–246、Flow 73：使用 `displayPrice`；加载失败禁购买并提供 Retry/Restore/Back。 |
| 错误不丢用户数据 | PASS（个别返回目标未决） | State Matrix 通用恢复 1–5；01–06 contract 16–21；PRD 311–317。 |

## 3. P0 阻断项

### P0-01：纸张尺寸的选择时点、默认值和 Book Check 失效规则未冻结

- PRD 143 要求 09 使用 `StoryPlanDraft + AlbumStyle + PDFPageSize` 创建文档，但 09 页面规格没有纸型控件、默认纸型或来源。
- Detailed State Specs 61 要求 Book Check 通过态绑定 `document revision + 纸张尺寸`。
- PRD 250–254 又允许 Final Preview 支持 A4/US Letter，但没有说明在 19 切换纸型后是否重新 Book Check、是否产生新 revision、是否允许直接导出。

因此无法唯一测试：09 应创建 A4、Letter 还是纸型无关文档；17 检查哪种纸型；19 切换纸型后原检查是否仍有效。

**必须裁决：**纸型首次选择页面与默认值；纸型是否属于 document revision；Book Check 缓存键；19 切纸型后的重新 resolve/check/阻断行为。

### P0-02：未生成文档档案的恢复入口和精确去向缺失

- PRD 74 承诺扫描、确认、故事规划、编辑和预览都可返回档案稍后继续。
- Flow 52 的 Archive 只给出 `10/05/系统预览`；PRD 263 的 `Continue editing` 仅描述“最近保存文档”。
- 但 03 保存 profile，04 保存参考照，06 保存 decision，07/08 保存 StoryPlanDraft；这些阶段尚无 `MemoryBookDocument`。

因此 App 重启或 Continue later 后，03、04、06、07、08、09 的档案卡状态、按钮文案和恢复页面没有唯一预期。

**必须裁决：**为每个 pre-document checkpoint 定义 Archive 状态、resumeRoute、主按钮与失效数据处理；至少覆盖 profile/reference/scan/review/smartDraft/storyPlan/stylePending。

### P0-03：拒绝照片权限后的“手动模式”流程未定义

- PRD 87 和 01–06 contract 8 表示拒绝后可手动选图。
- Flow 34 的成功去向写为“03 或手动模式”，但没有手动模式页面、选图范围、最少数量、是否跳过扫描、如何进入 Photo Review/Smart Draft。

因此无法测试 denied 分支的完整退出条件，也无法判断手选的是参考照、候选照片还是最终入册照片。

**必须裁决：**手动模式的页面归属与完整路线、PHPicker 数据范围、最少/最多数量、是否生成本地索引、结果如何进入 06、后续权限变化如何合并。

### P0-04：参考照或宠物身份变化后的扫描复用/失效规则缺失

- 01–06 contract 11 规定成功后只增量处理新增照片。
- 同一合同允许 04 替换参考照，05/06 也存在 Back；PRD 将参考照作为识别目标。
- 文档没有区分“与宠物无关的照片特征索引”与“依赖参考照的匹配结果/置信度/人工 decision”。

因此更换参考照、宠物类型或档案身份后，旧的 114 个匹配是全部保留、仅新照片重算，还是对已有索引重新匹配，均有合理解释。

**必须裁决：**索引与匹配结果的版本键；哪些字段变化触发全库重新匹配但复用 embedding；人工 decision 是否保留、失效或进入复核；进度和恢复语义。

### P0-05：敏感照片“显式确认”与入册过滤规则互相无法闭合

- 01–06 contract 20 要求敏感素材必须显式确认。
- PRD 93 和 contract 12 又规定任何仍为 `sensitive` 的照片均不得进入后续。
- 文档没有 `sensitiveApproved/allowUse` 等状态，也没有确认后是清除 sensitive 标签、增加 override，还是永远不可入册。

这会直接影响内容安全和“至少 3 张可入册”的计算，测试无法得到唯一 expected result。

**必须裁决：**敏感照片的状态机、确认文案、是否允许入册、四层过滤使用哪个最终字段；`neverUse` 必须明确不可被普通确认覆盖。

## 4. P1 缺口

| ID | 缺口 | 影响与最小裁决 |
| --- | --- | --- |
| P1-01 | 样章页数冲突 | PRD/Flow/State Matrix 为 6–8 页，Traceability 9 写“8 页”。统一为固定 8 页或规则化 6–8 页，并定义素材不足时准确页数。 |
| P1-02 | 03 年份校验不唯一 | “年份边界错误”没有范围；离开年份是否必填也未明确。定义 required、最小/最大年份、到家≤离开、未来年份、空值。 |
| P1-03 | 07 Cancel/Continue later 去向不唯一 | 定义取消回 06 还是 Archive、是否删除本次 partial StoryPlanDraft、恢复是继续计算还是从最后成功步骤重跑。 |
| P1-04 | 08 首次/已有文档共用文案冲突 | PRD 120 写标题说明“直接更新文档”，129 又裁决首次只更新 StoryPlanDraft；Flow 始终显示 `Create first draft`。需分别定义首次与已有文档按钮和保存对象。 |
| P1-05 | Book Check 规则缺少可测阈值 | “安全裁切、低 PPI、主体靠边、疑似重复、节奏重复”无阈值或确定算法版本。冻结 fixture 与阈值，或明确这些只做人工验收。 |
| P1-06 | Export 成功后的导航不唯一 | Flow 为 19→20，PRD 只规定持久化与 Share Sheet。定义成功后停留 19、自动到 20，或 Share Sheet 关闭后的目标。 |
| P1-07 | 01–06 与 Purchase/Archive 缺独立 v2 视觉态 | Prototype Map 仍直接链接 v1；合同声明 v1 仅视觉参考。功能状态可测，但像素级组件、层级、按钮位置和异常态没有唯一 v2 视觉 expected result。 |
| P1-08 | Debug bypass 发布边界未定义 | PRD 允许 Debug bypass 进入 19，但未规定 Release/TestFlight/App Store 的编译与验收隔离。必须明确生产构建不可达及对应测试。 |

## 5. 分项门禁

| 审计维度 | 判定 | 说明 |
| --- | --- | --- |
| 进入条件/主流程 | FAIL | denied 手动模式、pre-document resume 不唯一。 |
| 07→09 产物创建时点 | PASS | StoryPlanDraft/MemoryBookDocument 边界一致。 |
| 01–06 状态与持久化 | FAIL | 手动模式、参考照变化、敏感确认状态机未闭合。 |
| 恢复 | FAIL | 未成册档案恢复路由缺失。 |
| 付费 | PASS（受纸型 P0 牵连） | entitlement、价格、失败基本规则明确；完整预览前的纸型检查链不明确。 |
| 错误/降级 | PASS WITH P1 | 基本不丢数据、重试和降级明确；Cancel/成功返回目标仍需补。 |
| 验收口径 | FAIL | 纸型/Book Check 与若干质量阈值无法形成唯一 expected result。 |
| 原型视觉 | FAIL/P1 | 有设计来源，但部分页面仅以旧稿作为视觉参考，不能直接做像素签字。 |

## 6. 下一阶段进入条件

1. 产品先裁决 P0-01～P0-05。
2. 同步修改 PRD、Flow、State Matrix、01–06 Contract、Traceability、Prototype Map/详细状态和 Freeze 单；不能只改一处说明。
3. 重新计算 SHA-256 并生成新冻结版本号。
4. QA 把每项裁决转成 Given/When/Then 验收用例，确认不存在两个合理 expected result。
5. P0 全部关闭后，才允许继续新的代码补齐、设计验收或测试派工；现有缺陷修复只能在不依赖上述歧义的范围内进行。

## 7. v2.2 候选冻结第二轮独立审计

- 候选版本：`Tailor-v2.2-docfreeze-2026-07-21`
- 新增输入：`v2_visual_contract_01_06_18_20.md`
- 复审结论：**FAIL，剩余 1 个 P0、1 个 P1。**
- 审计边界：只复核文档与 SHA，不审代码、不改变产品合同。

### 7.1 冻结完整性

Freeze 单列出的 8 个文件当前 SHA-256 全部匹配：

| 文件 | 结果 |
| --- | --- |
| `Tailor_v2_PRD.md` | PASS |
| `prototype_map.html` | PASS |
| `flow_and_screen_contract.md` | PASS |
| `state_matrix.md` | PASS |
| `v2_pages_01_06_contract.md` | PASS |
| `v2_visual_contract_01_06_18_20.md` | PASS |
| `prd_prototype_traceability.md` | PASS |
| `detailed_state_specs.md` | PASS |

这证明候选文件没有发生 Freeze 单之外的内容漂移，但不等同于语义门禁自动通过。

### 7.2 上一轮 5 个 P0 回归

| 旧 ID | v2.2 结果 | 关闭证据 |
| --- | --- | --- |
| P0-01 纸型/检查失效 | **CLOSED** | 09 默认 US Letter、可选 A4；纸型属于 revision；Book Check 缓存键为 revision+paper+rulesVersion；19 切纸型创建新 revision、resolve 并重跑检查。 |
| P0-02 pre-document 恢复 | **CLOSED** | PRD 3.2、Flow 20、State Matrix `ArchiveCheckpoint` 统一为八类 checkpoint，并定义动态按钮和 03–10 resumeRoute。 |
| P0-03 denied 手动模式 | **CLOSED** | 02→03→04 Manual Import→06；PHPicker 3–500 张、pending decision、App 私有副本、无全库扫描及后续 PHAsset 指纹映射均已冻结。 |
| P0-04 识别代际 | **CLOSED** | embedding 与宠物身份解耦；reference/species/matcher 形成 match generation；参考照/狗猫变化复用 embedding 全量重匹配，旧 decision 变 stale 并须复核。 |
| P0-05 sensitive 闭环 | **CLOSED** | decision 与 sensitivity 分离；`selected + sensitiveApprovedAt` 可用，neverUse 永不可覆盖，四层复用统一 eligibility。 |

### 7.3 上一轮 8 个 P1 回归

| 旧 ID | v2.2 结果 | 说明 |
| --- | --- | --- |
| P1-01 样章页数 | **REMAINING / P1** | 已统一为 `min(8,totalPageCount)`、正常 8、最少 6，但允许的最小输入是 3 张照片；若三张均在同一时段，仍无法同时满足“至少两个不同时段章节页”、不虚构内容和最少 6 页。需定义该边界的说明页/单时段替代规则，或明确生成器保证 totalPageCount≥6 的非虚构结构。 |
| P1-02 年份校验 | **CLOSED** | 名称、类型、离开年份必填；范围 1900…当前年；到家年份可空且不得晚于离开年份。 |
| P1-03 Smart Draft Cancel/Later | **CLOSED** | Cancel 丢弃本轮未完成计算回 06、保留最近成功 draft；Later 保存完整步骤游标进 20，恢复不重新扫描。 |
| P1-04 Story Plan 首次/已有文档 | **CLOSED** | 首次按钮 `Choose book style`、只保存 StoryPlanDraft；已有文档为 `Save story changes`、更新章节语义并标记 needsReflow。 |
| P1-05 Book Check 阈值 | **CLOSED** | PPI、主体安全区、focal point、near duplicate、连续配方和 CoreText overflow 均有规则；规则版本变更会失效旧结果。 |
| P1-06 导出成功去向 | **CLOSED** | 导出和 Share Sheet 结束停留 19；用户点击 Done/View in Archive 才进入 20。 |
| P1-07 01–06/18/20 v2 视觉输入 | **CLOSED（文档阶段）** | 新视觉合同冻结基准画布、token、固定层级、关键状态和验收边界；实际新 v2 截图仍是设计实施证据，不再是 PRD 可测试性歧义。 |
| P1-08 Debug bypass | **CLOSED** | 只允许 DEBUG + 显式 UI-test 参数；Release/TestFlight/App Store 不可达并要求 Release 配置测试。 |

### 7.4 新 P0：returnContext 与 revision/Book Check 状态机冲突

候选文档定义了 `ReturnContext = sourceScreen + logicalPageID + issueID/issueIndex`，但尚未定义“编辑产生新 revision”时如何满足 17/19 的进入条件：

1. 17 的检查结果绑定 `documentRevisionID + PDFPageSize + rulesVersion`，任何 revision 变化立即失效。
2. 11 的编辑自动保存并产生最新 revision；Flow 却规定从 17 issue 进入 11 后直接回 17 原 issue，从 19 进入 11 后直接回 19 原 logicalPage。
3. 编辑后旧 issue 可能已消失、排序改变或产生新 issue；此时“恢复原 issueIndex”没有唯一预期。
4. 19 的进入条件是当前 revision Book Check 无阻断。若 11 修改后直接回 19，旧检查已失效，文档没有说明自动重跑、loading、发现阻断后的返回路径，还是禁止直接回 19。
5. 16 从 11 进入时，Flow 要求回 11；Freeze 单却写“11、16、18 均按 returnContext 回到 10/17/19”，对 16 是回即时来源 11 还是越级回根来源存在冲突。单层 `sourceScreen` 也没有定义嵌套 context 的保存规则。

因此以下测试均存在两个合理 expected result，属于导航和导出安全 P0：

- Book Check issue → Editor 修复 → 返回；
- Final Preview → Editor 修改 → 返回；
- Book Check/Final Preview → Editor → Apply Style → Cancel/Apply → 返回。

**必须裁决并同步所有冻结文档：**

- `ReturnContext` 是栈、父子 context，还是只保存 root source；16 从 11 返回 11 时不得覆盖 11 的 parent context。
- 任何 editor/style/layout 操作产生新 revision 后，返回 17/19 前必须采用哪种重新 Book Check 策略。
- 旧 issue 消失时的稳定 fallback：原 issueID → 同 page 下一 issue → 全书下一 issue → pass summary，并定义滚动位置。
- 19 返回链发现 blocking 时应进入 17；仅检查通过才恢复原 logicalPageID，若该页因 reflow 消失还需定义最近合法页 fallback。

### 7.5 v2.2 门禁

| 审计维度 | 判定 |
| --- | --- |
| 07→09 产物边界 | PASS |
| 01–06 功能/状态/恢复 | PASS |
| 纸型、Book Check 规则 | PASS |
| Purchase/Export 基本边界 | PASS |
| returnContext + revision 导航 | **FAIL / P0** |
| 样章最小素材边界 | **FAIL / P1** |
| Freeze SHA | PASS |

最终结论：**候选 v2.2 不能签署为无 P0。先关闭 returnContext/revision P0，并补齐样章最小素材 P1，再生成新的 SHA 与冻结结论。**

## 8. v2.2 候选冻结第三轮最终审计

- 复审结论：**FAIL，剩余 1 个新 P0，0 个 P1。**
- 审计边界：只审冻结文档，不审代码。

### 8.1 SHA 与上一轮缺口

Freeze 单列出的 8 个 SHA-256 与当前文件逐项一致，冻结完整性 PASS。

| 回归项 | 结果 |
| --- | --- |
| 第一轮旧 5 个 P0 | 全部 CLOSED，维持第 7.2 节结论。 |
| ReturnContext/revision P0 | **CLOSED**：已改为 `ReturnContextStack`；16 从 11 进入只回 11；11 离开前自动复检；blocking→17，通过→19；issue/page 均有稳定 locator 与 index fallback；复检前不显示旧 revision。 |
| 第一轮旧 8 个 P1 | 全部 CLOSED：单时段样章明确不虚构时期，使用真实献词/注记页组成结构；其余维持第 7.3 节关闭结论。 |
| match generation | PASS：`matchGenerationID` 明确包含 profileID、species、referenceSetFingerprint、matcherVersion。 |
| Book Check rules version | PASS：独立固定为 `bookCheckRulesVersion = 1`，不与 PRD 版本绑定。 |

### 8.2 新 P0：10→18 购买成功可绕过当前 revision 的 Book Check

三份冻结规则组合后仍存在一个不可接受的双重预期：

1. Flow 将 18 的进入来源定义为 `17 / 10 受限完整预览`。
2. Flow 将购买或恢复成功统一定义为 `18 → 19`。
3. PRD 将 19 的硬进入条件定义为“当前 Book Check 无阻断 + 已购买/恢复/Debug”。
4. 新的 revision 与纸型规则要求任何未检查或已失效的 revision 不得展示 Final Preview。

从 17 进入 18 时，当前 revision 已完成检查，成功后进入 19 合法；但从 10 直接进入 18 时，文档没有保证当前 revision 已执行 Book Check。此时购买/恢复成功是直接进入 19，还是先自动检查并按 blocking/pass 分流，存在两种合理实现。直接进入会绕过内容、字体、裁切和缺图阻断。

**必须裁决：**

- 方案 A：删除 10→18，所有完整预览/导出尝试都必须先 10→17，再由 17→18/19。
- 方案 B：保留 10→18，但成功后自动对当前 revision+paper+rulesVersion 执行 Book Check；blocking→17，pass→19，检查期间不得展示旧 Final Preview。购买权益必须保留，不因检查失败回滚。
- 同步更新 Flow、PRD Purchase/Final Preview、State Matrix、Traceability、Freeze 单及 SHA。

### 8.3 最终门禁

| 维度 | 判定 |
| --- | --- |
| 01–09 产品与产物边界 | PASS |
| 状态、恢复、识别代际、敏感规则 | PASS |
| ReturnContextStack 与编辑后复检 | PASS |
| 样章最小素材 | PASS |
| Book Check 阈值与 rulesVersion | PASS |
| 付费取消/失败返回 | PASS |
| 购买成功进入 Final Preview | **FAIL / P0** |
| Freeze SHA | PASS |

最终结论：**第三轮仍不能签署最终 PASS。除 10→18 成功后的 Book Check 门禁外，前两轮全部 P0/P1 已关闭；关闭该 P0 并更新 SHA 后才可签署文档冻结。**

## 9. v2.2 最终增量审计签署

- 最终结论：**PASS。**
- 剩余需求歧义：**P0 = 0，P1 = 0。**
- 审计边界：这是 PRD/原型文档的可测试性签署，不代表代码实现、视觉像素、真机、StoreKit 沙盒或内容质量实施门禁已经通过。

### 9.1 最后 P0 关闭

`10 → 18` 已从冻结流程中删除，付费链路形成唯一预期：

1. 10 只能先进入 17 Book Check。
2. 18 仅允许从“当前 document revision + paper size + rulesVersion 无阻断”的 17 通过态进入。
3. 购买或恢复成功进入 19；取消、失败和恢复失败回到 17 相同通过态，不丢草稿。
4. 购买权益保留；购买后的编辑、重排或纸型切换产生新 revision 时仍必须重新 Book Check。
5. 当前 revision 未完成复检时不得展示旧 Final Preview。

PRD、Flow、State Matrix、Traceability 和 Freeze 单的上述语义一致，未发现可以从 10 或其他页面绕过 17 的第二条产品路径。第三轮第 8.2 节 P0 因此 **CLOSED**。

### 9.2 最终 SHA 核对

Freeze 单 8 个 SHA-256 与当前文件全部一致：

| 文件 | SHA-256 | 结果 |
| --- | --- | --- |
| `Tailor_v2_PRD.md` | `289ba9d154b24218900af3c9415768fdfc3d41cb5881c167f3cadf39c304840c` | PASS |
| `prototype_map.html` | `ec00118b4970203d71b0cc95adf583dfde9558e0c2ad785cd8d4e0992d27ba77` | PASS |
| `flow_and_screen_contract.md` | `0f865e8deba628705944d101f98134cb3893cd16efae928a3846132b7a164b3c` | PASS |
| `state_matrix.md` | `5338477d954a81d83fe040dfe907c9491bc67e60488709eed15bc3010396803e` | PASS |
| `v2_pages_01_06_contract.md` | `3f736d013d0da30ed2cc797ce84ea5ab7a0e0c633624369188c70c7932ec3ffd` | PASS |
| `v2_visual_contract_01_06_18_20.md` | `3c655182a4895c5e4185879d80850731b8f84d6792a240f0314a73e320755a8d` | PASS |
| `prd_prototype_traceability.md` | `907184ec6ccde1eaeb73f91ce90709522d7cea4916d6498a1f372208835e8855` | PASS |
| `detailed_state_specs.md` | `caa58f0e6414d218f537c96792f50e351c32b1eee4e95d7d6d85c37e1f7e3d72` | PASS |

### 9.3 最终门禁状态

| 维度 | 最终判定 |
| --- | --- |
| 01–20 主流程与进入/退出条件 | PASS |
| 07→09 StoryPlanDraft / MemoryBookDocument 创建时点 | PASS |
| 01–06 权限、手动导入、识别代际、敏感状态 | PASS |
| Archive checkpoint 与恢复 | PASS |
| ReturnContextStack、revision、issue/page fallback | PASS |
| 样章页数与单时段不虚构规则 | PASS |
| Book Check 阈值、缓存键和 rulesVersion | PASS |
| Purchase、取消/失败、恢复和 Final Preview 门禁 | PASS |
| 错误、降级与数据保护 | PASS |
| 冻结文件完整性 | PASS |

**签署意见：Tailor v2.2 PRD 与原型文档已能形成唯一功能测试预期，可以进入冻结范围内的设计、研发和测试实施。不得把本签署外推为 `QA-V2-005`、真机、真实 StoreKit、GF-01～GF-04 或 20 本质量门禁通过。**
