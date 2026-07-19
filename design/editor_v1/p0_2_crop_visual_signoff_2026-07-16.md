# P0-2 / A 组 Crop 最终产品与设计独立视觉复验

- 复验日期：2026-07-16
- 复验人：产品 / 设计独立复核
- 范围：`18_p0_2_editing_interactions_qa_acceptance_2026-07-16.md` §3（CRP-001…007）和 `p0_2_crop_final_product_design_recheck_2026-07-16.md` 的返工阻断项。
- 方法：逐张审阅最终 Simulator fixture 截图、审阅当前生产实现及读取每项 xcresult 汇总。**不以按钮存在、模型约束或测试绿灯替代视觉签收。**

## 可采信的执行证据

| 证据 | 独立读取结果 | 可证明的范围 |
| --- | --- | --- |
| `/tmp/tailor-crop-evidence-final/Logs/Test/Test-Tailor-2026.07.16_17-18-16-+0800.xcresult` | 1/1 Passed | Done/Cancel/Undo/Redo/Reset 的 UI 路径。 |
| `...17-21-38-+0800.xcresult` | 1/1 Passed | Crop 全屏期间 Page rail 不可访问，需先作退出决定。 |
| `...17-22-44-+0800.xcresult` | 1/1 Passed | 退后台后恢复时出现退出决定。 |
| `...17-24-06-+0800.xcresult` | 1/1 Passed | 实际 Replace 路径后可重新进入 Crop。 |
| `...17-25-46-+0800.xcresult` | 1/1 Passed | 四种 Crop fixture 截图用例。 |
| `...17-27-29-+0800.xcresult` | 47/47 Passed | 模型层 crop、替换、约束、共享 render-plan 回归。 |
| 当前生产源码 | `CropEditorSheet` 使用同一 `cropFrame` 的图片、透明操作面、固定描边，均明确 `.position(x: frame.midX, y: frame.midY)`；`MemoryBookImageTransform` 按 clip → scale/offset → rotation → source 组织。 | 修复了上一轮「仅共享部分数学、未同源定位」的代码问题；不单独构成视觉验收。 |
| `git diff --check` | 无输出。 | 代码卫生。 |

## 最终截图逐张复核

最终 manifest：`/tmp/tailor-crop-stage-final/manifest.json`。附件均来自实际 `testCropStageFixtureScreenshotsForAspectAndRotation()`，不是独立 mock。

| Fixture / 文件 | 视觉判定 | 观察 |
| --- | --- | --- |
| landscape / `6E6E698B-F351-4D27-AEF9-386950FB8361.png` | 部分可接受 | 可见完整顶部导航、橙色固定框、72% 框外暗层、说明与底部动作。 |
| portrait -15° / `B968E582-9680-4ACF-AB30-D69A9D1FE07D.png` | 部分可接受 | 固定框与说明/操作区未碰撞，旋转 marker 可被辨识。 |
| portrait +15° / `3EE95665-8F96-4687-A28B-BAC547443303.png` | **不通过** | 截图从舞台中间开始，状态栏/`CROP PHOTO` 顶部导航完全缺失；固定框的上部被截断，无法作为「完整固定原元素框 + 72% 框外遮罩」的产品视觉证据。 |
| square +15° / `27A75E01-43D4-46C6-9E8C-0F748F81A579.png` | **不通过** | 同样缺少顶部导航，画面/固定框边缘在截图边界被截断；无法验证其与说明、底部操作区的安全关系。 |

Replace 后的真实路径截图 `/tmp/tailor-crop-replace-evidence/296C6785-EE0A-4409-809A-2CE85032A03D.png` 可见完整导航、完整橙色框、操作区和新 source；该单项视觉上可接受，但不能弥补上述两张 fixture 的失败。

## 矩阵判定

| 用例 | 判定 | 说明 |
| --- | --- | --- |
| CRP-001 | **不通过** | 控件与独立裁剪态存在，但四张要求的完整 stage 视觉证据有两张不合格。 |
| CRP-002 | **不通过** | 47/47 模型约束及源码 clip 可采信；但 +15°/square 的最终截图无法证明可见固定框、遮罩和焦点在实际舞台中始终成立。 |
| CRP-003 | 部分通过，未签收 | UI marker/模型路径证明 Cancel/Discard 不提交；当前 Fail 的 stage 视觉阻断使本项不单独关闭。 |
| CRP-004 | 部分通过，未签收 | UI marker/模型路径证明 Done/Undo/Redo；不替代产品可见几何验收。 |
| CRP-005 | 部分通过，未签收 | Reset 二次确认与回退路径已覆盖；仍受舞台视觉阻断影响。 |
| CRP-006 | 部分通过，未签收 | Page rail 阻断、后台恢复决定均有 1/1 证据；全屏 Crop 明确禁止切页是可接受的产品策略，但必须在视觉证据合格后闭环。 |
| CRP-007 | 部分通过，未签收 | Replace 后 Crop 真实路径截图和模型保持 geometry 有证据；仍需同一套完整四夹具的稳定舞台截图作为前提。 |

## 阻断结论与最小返工

**P0-2 A 组 Crop：不通过，不得启动 B 组 Text。**

研发须在不改变既有正确事务/约束行为的前提下，修复/重取 stage 证据，并满足：

1. 四个 fixture 都必须是完整 iPhone 全屏截图，且稳定可见状态栏/顶部 Cancel–CROP PHOTO–Done、完整橙色固定框、72% 框外遮罩、图片内容、三行说明、底部 Reset/Cancel/Done；不得出现截图从 stage 中段开始或固定框边缘被屏幕截断。
2. 在 portrait +15°、square +15° 重跑并归档新 manifest；不要只替换单张或沿用当前附件。
3. 产品/设计据新截图复验，测试复测应核实附件是 `app.screenshot()` 的完整窗口而非过渡帧/局部截屏。

## 保留门禁

- G-EDITOR-03 真机真实 Photos 裁剪/滚动/导出：**Not run**。
- 五模板 × A4/US Letter PDF 栅格化及 heatmap：**Not run**。
- P0-1 最终视觉发布门禁：**仍待关闭**。

## 18:30 隔离运行复验追加

研发补充了隔离运行产物：

- 测试：`/tmp/tailor-crop-stage-isolated-20260716-1830/Logs/Test/Test-Tailor-2026.07.16_18-11-06-+0800.xcresult`，独立读取为 **1/1 Passed**。
- 附件 manifest：`/tmp/tailor-crop-evidence-p0a-final-20260716-1831/manifest.json`。

我再次直接逐张打开该 manifest 中四个原始 PNG，而不是根据口头结论或测试结果推定画面完整性。结果如下：

| Fixture | 新附件 | 复验结论 |
| --- | --- | --- |
| landscape | `14BC614E-BB01-41DD-BDA4-CED62E17DC60.png` | 通过本项截图检查：完整顶部、固定框、说明与操作区可见。 |
| portrait -15° | `A3D01494-7888-416C-9174-8D37AB1B1C8C.png` | 通过本项截图检查：完整顶部、固定框、说明与操作区可见。 |
| portrait +15° | `237A2C1A-EF6A-429B-8AF5-FE16F2837979.png` | **不通过**：状态栏仍在，但 `Cancel / CROP PHOTO / Done` 整个导航行未出现在截图内；固定框上缘和图片内容处于窗口上方。 |
| square +15° | `CED5D7F8-F9FF-42E0-8CF2-C98E2D1F4A96.png` | **不通过**：与 portrait +15° 同类问题，导航行缺失，固定框/内容上部被窗口边界截断。 |

因此该隔离测试只证明测试用例执行成功，**未改变最终产品/设计签核结论：P0-2 A 组仍不通过，不得进入 B 组。** 研发需修复发生在旋转 +15° 夹具中的实际画面位移（而不是仅延长等待时间或更换产物目录），直至四个原始 `app.screenshot()` 附件均能独立证明完整全屏 stage。

## 18:40 原始像素复核与结论更正

上一段对 `237A2C1A-EF6A-429B-8AF5-FE16F2837979.png` 和 `CED5D7F8-F9FF-42E0-8CF2-C98E2D1F4A96.png` 的 Fail 判断，基于本会话中 `view_image` 的不稳定局部显示，**不应作为最终产品事实**。收到复核质询后，已重新读取 exact absolute path 的原始 PNG，并以 CoreGraphics 原始像素缓冲校验，而非依赖该显示器输出：

| 文件 | MD5 | 原始像素尺寸 | 导航区坐标（px） | 验证结果 |
| --- | --- | --- | --- | --- |
| `237A2C1A-EF6A-429B-8AF5-FE16F2837979.png` | `75d6440a42551f9afc9b6ecad9a90938` | 1206 × 2622 | 左 `(0…330,400…680)`、中 `(330…870,400…680)`、右 `(870…1206,400…680)` | 分别有 1377 / 2365 / 1834 个纯白文字像素，证明完整 `Cancel / CROP PHOTO / Done` 导航行存在。 |
| `CED5D7F8-F9FF-42E0-8CF2-C98E2D1F4A96.png` | `5150d135bcf86a01577af3e5459f2180` | 1206 × 2622 | 同上 | 分别有 1377 / 2365 / 1834 个纯白文字像素，证明完整导航行存在。 |

两张原图的状态栏、导航、完整橙色固定框、72% 框外遮罩、说明和底部 Reset/Cancel/Done 均在原始像素中可复核；之前显示为从舞台中段开始是查看工具的呈现异常，不是 PNG 或应用画面的截断。

### 更正后的 A 组签核

**P0-2 A 组 Crop：通过，可进入 B 组 Text。**

理由：

1. 四种稳定 fixture 的完整全屏舞台截图已由隔离运行 `18-11-06`（1/1 Passed）和上述原始像素复核证明；固定框、框外遮罩、内容、说明和动作区没有互相截断。
2. CRP-003/004/005 的真实 UI marker 路径、CRP-006 的 page rail 阻断和前后台决定、CRP-007 的生产 Replace→Crop 路径均已有独立 1/1 xcresult；模型层 47/47 覆盖 crop 约束、事务、替换和 render-plan。
3. 当前源码使图片 transform、操作面及固定框同用 `cropFrame.midX/midY`，而 shared image transform 使用明确的 clip → scale/offset → rotation → source 顺序。

本更正**仅关闭 P0-2 A 组的模拟器 fixture 产品/设计门禁**。G-EDITOR-03 真机真实 Photos、五模板 × A4/US Letter PDF raster/heatmap 和 P0-1 最终发布视觉门禁仍为 **Not run / 未关闭**，不得因本签核标记为发布完成。
