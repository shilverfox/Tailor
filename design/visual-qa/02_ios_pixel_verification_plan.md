# Tailor iOS 01–12 像素级视觉验证执行方案

## 0. 门禁与设计基线

目标是把每个 iOS 页面在**同一设备、同一数据、同一状态**下与权威设计逐像素对照，而不是仅确认“页面能打开”。

- 基准尺寸：**390 × 844 px（1× 设计坐标）**，iPhone portrait。
- 唯一像素设计参照：[`reference_manifest.md`](reference_manifest.md) 标记为 **`approved`** 的 `design/reference/v1_1/<page>-<state>.png`。
- 规则优先级：最新版 PRD 的安全/功能要求 > `ui_scope_contract.md` > `reference_manifest.md` 的 approved PNG。`ui_spec.md` 与 `v1_1_design_delta.md` 只定义行为/组件规则，不能单独用于像素通过。
- 通过前提：manifest 对应状态为 `approved`、其 390×844 PNG 实际存在，且运行截图可追溯到确定的 Git revision、模拟器、路由和数据集。
- **严禁误判**：缺少对应权威设计页、设计页与规格冲突、仅有历史截图、或仅验证 demo 壳但未验证指定状态，均为 `BLOCKED`，绝不可记为 PASS。

### 0.1 设计冲突处理

如 manifest 中该状态不是 `approved`，或 `design/reference/v1_1/` 缺少对应的 390×844 PNG（例如 06 敏感素材、09 8 页水印、10 失败、11 渲染），该状态的结果应记为：

`BLOCKED — DESIGN_BASELINE_MISSING`。

设计师须提供同尺寸、同状态的 `design/reference/v1_1/NN-<state>.png`，并由产品将其登记为 `approved` 后，才允许比较和签收。工程/测试不得根据代码自行制作“目标图”。

`design/screens/01.png`–`12.png`、`design/prototype.html` 与 `design/prototype_v1_1.html` **全部不是像素基线**；即使尺寸相同，也不得复制、叠图、采样或用于 PASS/FAIL 判断。

## 1. 固定环境

| 项 | 固定值 |
| --- | --- |
| Simulator | `Tailor-QA-iPhone13`，iPhone 13，390×844 pt，3×截图（1170×2532） |
| Runtime | 本次构建使用的 iOS Simulator runtime；报告必须写明版本与 build number |
| 外观 | Light mode、标准文字大小、100% Display Zoom、Reduce Motion 关闭 |
| 网络 | 标准页面：无关；离线状态另立功能验证，不混入像素基线 |
| 数据 | `-uiTesting -uiDemoRoute <route>` 提供的固定 Milo 文档；每个状态须有固定 fixture，不可用真实照片库随机结果 |
| 截图时机 | 首帧稳定后，动画停止、键盘收起、无系统权限/Share Sheet 覆盖层 |

建议创建专用模拟器（只需一次）：

```bash
RUNTIME=$(/usr/bin/xcrun simctl list runtimes | /usr/bin/grep -m1 'iOS.*available' | /usr/bin/sed -E 's/.*\((com\.apple\.CoreSimulator\.SimRuntime\.[^)]+)\).*/\1/')
/usr/bin/xcrun simctl create Tailor-QA-iPhone13 com.apple.CoreSimulator.SimDeviceType.iPhone-13 "$RUNTIME"
```

报告中固定记录产生的 UDID；不得在 iPhone 16/17 的 393pt 宽截图上直接拉伸后冒充 390pt 基线。

## 2. 目录、命名与可追溯性

所有本轮结果放在 `design/visual-qa/results/<YYYYMMDD>-<git-short-sha>/`：

```text
results/<run>/
  manifest.md
  reference/01-welcome.png
  runtime/01-welcome-standard@3x.png
  normalized/01-welcome-standard.png
  overlay/01-welcome-standard-overlay.png
  diff/01-welcome-standard-diff.png
  metrics/01-welcome-standard.json
  report.md
```

命名格式：`NN-<route>-<state>`，例如 `06-confirm-sensitive`、`09-preview-free-page-01`、`11-export-rendering`。

`manifest.md` 每一行必须包含：Git SHA、Xcode/Runtime、模拟器 UDID、App build、launch arguments、fixture ID、截图 UTC 时间、参照设计文件 SHA-256。

## 3. 截图执行通路

### 3.1 构建、安装、路由启动

以下示例使用已知工程路径和 bundle ID；`SIMULATOR_UDID` 必须替换为第 1 节冻结的 QA 设备。

```bash
PROJECT=/Users/lijian15/iosWork/Tailor
SIMULATOR_UDID=<Tailor-QA-iPhone13-UDID>
APP="$HOME/Library/Developer/Xcode/DerivedData/Tailor-atyczrlhkknoriamyexrsjxildgn/Build/Products/Debug-iphonesimulator/Tailor.app"

cd "$PROJECT"
/usr/bin/xcodebuild build -project Tailor.xcodeproj -scheme Tailor \
  -destination "platform=iOS Simulator,id=$SIMULATOR_UDID"
/usr/bin/xcrun simctl boot "$SIMULATOR_UDID" || true
/usr/bin/xcrun simctl bootstatus "$SIMULATOR_UDID" -b
/usr/bin/xcrun simctl install "$SIMULATOR_UDID" "$APP"
/usr/bin/xcrun simctl launch --terminate-running-process "$SIMULATOR_UDID" \
  com.tailor.prototype -uiTesting -uiDemoRoute welcome
```

对 12 个标准页循环替换 route：

| 设计页 | route | 默认截屏状态 |
| --- | --- | --- |
| 01 | `welcome` | standard |
| 02 | `privacy` | not-determined（另验 limited / denied） |
| 03 | `profile` | valid form |
| 04 | `references` | 3 selected |
| 05 | `scan` | running（另验 paused / failed） |
| 06 | `confirm` | high/needs-review/sensitive/excluded（分状态） |
| 07 | `timeline` | 3–6 chapters，另验 hidden periods collapsed |
| 08 | `chapter` | selected chapter with cover + note |
| 09 | `preview` | free, Warm Paper, page 1；另验全部 8 页和其他模板 |
| 10 | `purchase` | idle（另验 purchasing / cancelled / failed / restored） |
| 11 | `export` | rendering / complete / failed |
| 12 | `archive` | populated（另验 empty / delete confirmation） |

截图命令（页面稳定后执行；不可依赖固定延时作为唯一稳定信号）：

```bash
/usr/bin/xcrun simctl io "$SIMULATOR_UDID" screenshot \
  "design/visual-qa/results/<run>/runtime/01-welcome-standard@3x.png"
```

优先使用 `TailorUITests` 的 `waitForExistence` 等待明确标题/控件，并通过 `XCTAttachment(screenshot:)` 附件留档。`simctl io screenshot` 用于可复现原始位图；XCUITest 附件用于证明截图前页面已到达预期路由。

### 3.2 统一 390×844 裁剪/缩放

唯一允许的标准截图是 iPhone 13 的 1170×2532（390×844@3x）。将其严格降采样到 390×844；不可裁去状态栏、Home Indicator 或拉伸其他机型截图。

```bash
INPUT='design/visual-qa/results/<run>/runtime/01-welcome-standard@3x.png'
OUTPUT='design/visual-qa/results/<run>/normalized/01-welcome-standard.png'
/usr/bin/sips -z 844 390 "$INPUT" --out "$OUTPUT"
/usr/bin/sips -g pixelWidth -g pixelHeight "$OUTPUT"
# 必须回显 pixelWidth: 390 / pixelHeight: 844
```

若原始文件不是 1170×2532，停止该页验证并标记 `BLOCKED — BASELINE_DEVICE_MISMATCH`。严禁用任意比例 resize 使其“看起来接近”。

## 4. 叠图与 diff 判定

### 4.1 生成物

每个待验状态必须包含四类文件：

1. `reference/`：仅从 manifest 已批准的 `design/reference/v1_1/` 原样复制，并在 manifest 中记录源文件 SHA-256。
2. `normalized/`：390×844 运行截图。
3. `overlay/`：reference 50% opacity 覆盖 runtime；绿色/洋红模式可辅助检查对齐。
4. `diff/` + `metrics/`：绝对像素差、热区图、差异比例、最大/平均色差、遮罩说明。

使用任意可复现图像工具均可（Core Image、ImageMagick、OpenCV）；命令和工具版本必须写入 manifest。推荐逻辑：

```text
assert reference.size == runtime.size == (390, 844)
overlay = alphaBlend(reference, runtime, 0.5)
diff = abs(reference.RGBA - runtime.RGBA)
mask = deltaE2000(reference, runtime) > threshold
write overlay, heatmap(mask), metrics JSON
```

### 4.2 阈值

视觉验收不是以总像素分数单独定输赢；以下阈值同时成立才可通过：

| 项 | PASS 阈值 | P0 失败条件 |
| --- | --- | --- |
| 页面几何 | 顶部导航、标题、卡片、底部 CTA：位移 ≤2 pt | CTA/关键交互、标题、主卡片位移 >4 pt 或被裁切 |
| 动态真实照片区域 | 图像裁切/缩放位移 ≤4 pt；照片区域可在 mask 中单独计量 | 将照片 mask 用于掩盖文字、卡片或布局差异 |
| 字体/文案 | 相同文本换行、字号层级、行高；无截断 | 关键标题/CTA/隐私/购买/删除文案不一致或截断 |
| 色彩/边框 | 关键 token 采样 RGB 差 ≤6；1 pt border 可辨识 | 纯白 Tailor surface、错误主题色、无边框/错误对比度 |
| 全图差异 | 去除明确照片 mask 后，`deltaE2000 > 8` 面积 ≤2% | 非照片区域差异 >5% 或出现大块错位 |
| 交互态 | 每个 P0 状态有独立参照+截图+附件 | 仅验证默认页即宣布整页通过 |

系统状态栏只在 reference 与 runtime 属于同一基线时参与比较；若设计页故意不含同版本状态栏，则仅允许设计师提供 status-bar mask。测试不得自行遮罩。

## 5. 01–12 逐页 P0 视觉清单

| 页面 | P0 必检项 | 必须留存的状态 |
| --- | --- | --- |
| 01 Welcome | 390pt gutters、标题换行、hero 3:2、底部 CTA/隐私入口均可见 | standard |
| 02 Privacy | 三项隐私说明、完整/受限/拒绝无死路、主/次 CTA 固定底部 | not-determined、limited、denied |
| 03 Profile | 猫狗状态、52pt 输入框、必填/年份关联错误、键盘不遮 CTA | valid、invalid-name、invalid-year |
| 04 References | 3:4 真实选图格、移除控件、0–2 禁用、≥3 启用 | empty、two-selected、three-selected、unavailable |
| 05 Scan | 深绿画布、进度/计数一致、缩略条、暂停/失败/完成行动 | running、paused、failed、complete |
| 06 Confirm | 四分组、年份过滤、真实缩略图；敏感/永不使用保护；待确认非自动入册 | high、needs-review、sensitive、never-use、zero-match |
| 07 Timeline | 年份轴、章节卡、隐藏时期无代表图、无证据中性标题 | standard、hidden-collapsed、hidden-expanded、empty |
| 08 Chapter | 选定章节上下文、标题/备注、九宫格、唯一封面、排序/删除态 | populated、empty-chapter、dirty-back-prompt |
| 09 Preview | 5:7 页面、三模板、免费 **8 页**逐页水印、素材不足说明、购买后去水印 | free-p01…p08、free-insufficient、quiet-night、field-notes、purchased |
| 10 Purchase | $19.99/一次性、权益清单、购买中禁重复、取消/失败不丢编辑状态 | idle、purchasing、cancelled、failed、restored |
| 11 Export | 纸张尺寸、渲染页进度、失败可重试、完成后本地封面/分享 CTA | choose-paper、rendering、failed、complete |
| 12 Archive | 本地封面、可点设置行、删除二次确认及空态 | populated、delete-sheet、empty、access-revoked |

## 6. 单页结果记录模板

每个截图状态在 `report.md` 使用一行；同页状态不得合并为一个模糊结论。

| ID | 设计参照 | 路由/fixture | 原始/规范截图 | 叠图/diff | 几何 | 文案/token | P0 行为 | 结论 | 缺陷 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 09-preview-free-p01 | `reference/v1_1/09-preview-unpurchased-page-1.png`（必须为 approved） | `preview/free-8p` | path | path | ≤2pt / fail | pass/fail | watermark pass/fail | PASS/BLOCKED/FAIL | QA-xxx |

结论定义：

- `PASS`：有权威参照、正确 fixture、所有 P0 清单和阈值通过。
- `FAIL`：有参照且视觉/状态偏差超过阈值；建立缺陷并附 overlay/diff。
- `BLOCKED`：缺权威设计、fixture、可读截图、有效截图附件或工具输出；不能被认为 PASS。
- `N/A`：PRD 明确不适用，必须由产品/设计书面批准；“尚未实现”不能写 N/A。

## 7. 最终签收条件

1. 01–12 的 standard 状态均 PASS，所有表中 P0 状态均 PASS 或由产品明确从 v1 移除。
2. 09 免费样章逐页留下 8 张截图/附件；每张有水印，且无法见到敏感、never-use、隐藏时期照片。
3. 02、05、06、10、11、12 的异常态均有对应权威设计，不用工程自制目标图。
4. `TailorUITests` 必须全绿，且每个 demo 路由截图附件可从有效 xcresult 提取。
5. 输出一次最终 diff 汇总：页面、状态、max drift、非照片差异面积、设计批准人、Git SHA。

在以上条件满足前，视觉验证状态应保持 **NOT APPROVED**。
