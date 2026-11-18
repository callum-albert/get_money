# 今日进账

原生 iPhone 桌面小组件 + 轻量 SwiftUI App。最低 iOS 17。

## 已实现

- 今日收入按有效工作秒数累积，App 前台每秒重算。
- 小/中尺寸 WidgetKit 小组件显示今日已赚、状态、进度和更新时间；点击打开 App。暂停与请假操作在 App 内完成。
- 月薪/日薪；月薪按当月计划工作日或固定计薪天数折算。
- 默认 09:00–18:00、12:00–13:00 午休、周一至周五，全部可改；午休可关闭。不支持跨夜班次。
- 暂停扣除实际重叠的工作时间，恢复不补算。暂停不会延续到下一天。
- 整天无薪请假，当日金额为零；月度明细可补记或撤销请假。
- 月度累计和每日明细，不回填首次配置前的工资。
- 设置按生效日期保存，修改只影响当天及以后，往日使用往日版本。
- 本地 JSON 原子保存，App Group 共享；不联网、不注册。

## 关于“实时”

普通 iOS 小组件不能持续运行计时器，也不能保证每秒/每分钟刷新。本项目提前生成未来 4 小时、通常每 5 分钟一帧的时间轴，并补入上下班、午休和午夜边界，最终展示和刷新仍受 iOS 调度。前台 App 的今日页可见时每秒重算，不依赖后台进程。小组件展示更新时间，避免将旧快照误认为精确实时数字。

## 轻量与节能策略

- 无第三方运行时依赖、网络请求、广告、分析 SDK、数据库或图片资源。
- 不申请后台任务、定位、通知或实时活动权限，不用后台常驻维持计薪。
- 今日页仅在选中且 App 活跃时启动一秒间隔刷新；离开该页或进入后台即暂停刷新。恢复后根据当前时间直接计算，不回放错过的秒数。
- 去掉金额逐秒过渡动画，减少额外渲染。
- 月度页不设定时器：进入页面、回到前台或下拉刷新时更新快照。
- 小组件常规时间轴从 241 帧降为 49 帧，另外补上关键工作边界；时间轴通常每 3 小时请求重建，受系统调度影响。此策略优先节能而非视觉秒刷。
- 不逐秒保存收入：只在改设置、暂停/恢复和标记/取消请假时原子写入紧凑 JSON，随后请求更新小组件。
- 正常工作日不创建收入明细存储，月度收入根据工资版本及例外记录按需计算，避免日积月累存储秒级流水。
- 这些是实现策略，不是实测耗电/内存承诺；仍需完整 Xcode 的 Instruments、真机 Energy Log 和归档包验证。`.build/` 是 Mac 开发缓存，不会打入手机 App。

## 下载与无 Xcode 构建

发布下载：[GitHub Releases](https://github.com/callum-albert/get_money/releases)。下载 Assets 中的 `today-earnings-1.0.0.ipa`，不要下载源码 ZIP 来安装。

IPA 使用 ad-hoc 临时签名，需要通过支持的侧载工具或自己的开发团队重新签名；主 App 和 Widget 扩展必须一起签名，并共享同一个有效 App Group。不能保证免费 Personal Team 或任意侧载工具支持该权限；权限缺失会显示共享容器错误。当前未完成真机安装验收。

本机已有独立 iOS SDK，无需完整 Xcode 即可构建：

```sh
./build.sh
# 其他 SDK 路径：
SDK=/path/to/iPhoneOS.sdk ./build.sh
```

需要 macOS、Command Line Tools（swiftc / codesign）和 Python 3。默认 SDK 为 `/tmp/sdkbuild/sdk/iPhoneOS27.2.sdk`，SDK 不包含在仓库中。输出位于 `build/`，包含 IPA 和 SHA256 文件。使用优化编译、静态链接本项目计算库，不打包第三方运行时。构建脚本不会绕过 iOS API 可用性检查。

## 使用完整 Xcode 在 iPhone 上运行（可选）

当前仓库已包含 `TodayEarnings.xcodeproj`，可直接用完整 Xcode 打开，不要只打开 `Package.swift`（它只是计算库）。

1. 从 Mac App Store 安装完整 Xcode，首次启动完成组件安装。
2. 必要时运行：
   ```sh
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```
3. 打开 `TodayEarnings.xcodeproj`，选择 `TodayEarnings` scheme。
4. 对 **TodayEarnings** 和 **EarningsWidgetExtension** 两个 target 的 Signing & Capabilities 选择同一个开发团队，并使用你自己的唯一 Bundle ID。
5. 在 Apple Developer 账户创建并启用一个 App Group，两个 target 使用同一组。当前示例为 `group.com.callum.TodayEarnings`，需要一起修改：
   - `Configuration/App.entitlements`
   - `App/SharedStore.swift` 的 `groupID`
   - 若重新生成工程，保持 `project.yml` 中的 Bundle ID 与实际配置一致。
6. 选择 iPhone 模拟器或已连接且开启开发者模式的 iPhone，运行 App。
7. 到“设置”保存自己的工资。长按桌面 → 编辑 → 添加小组件 → 今日进账。

**签名提醒：** App Groups 通常需要加入 Apple Developer Program 的开发团队；免费 Personal Team 可能无法签署该能力。若签名不支持，不代表代码能绕过此限制。可先在模拟器验证，真机共享容器需要正确的 App Group 权限。

未配置共享容器或数据损坏时会明确报错，不会静默使用独立存储或覆盖旧数据。示例工资 10000 元只有保存后才启用，并非真实用户数据。

## 开发和验证

工程配置源为 `project.yml`，改动后可重新生成：

```sh
brew install xcodegen
xcodegen generate
```

独立计算库：

```sh
swift build
swift test
```

仅装 Command Line Tools 且缺少 XCTest 时，也可运行不依赖测试框架的回归校验：

```sh
swiftc Sources/EarningsCore/Earnings.swift Scripts/verify-core.swift -o /tmp/get-money-verify
/tmp/get-money-verify
```

完整 Xcode 环境下构建模拟器：

```sh
xcodebuild -project TodayEarnings.xcodeproj -scheme TodayEarnings \
  -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

### 本次验证结果

- `swift build`：通过。
- 独立 Swift 回归检查：19 项通过。
- `swiftc -frontend -parse App/*.swift Widget/*.swift`：语法解析通过，**不等于 iOS SDK 类型检查或编译通过**。
- 工程生成及 plist 校验：通过。
- `swift test`：当前 Command Line Tools 缺少 XCTest，未能执行；已保留 XCTest 用例供完整 Xcode 环境运行。
- 使用独立 iOS SDK 实际编译主 App 和扩展：通过；`vtool` 确认均为 IOS 平台，最低 iOS 17.0。
- IPA 临时签名校验及 ZIP CRC/结构校验：通过；初版 IPA 约 1.06 MB。
- 编译工具输出 SDK/sysroot 及本机 Swift 库目录警告，但链接完成，已核对产物平台。仍需真机验证运行兼容性。
- **尚未完成模拟器运行、视觉验收、真机重签名安装及小组件刷新验证**。

## 计算约定与限制

- 金额为税前估算，不是工资单，不自动计算税费、加班、法定节假日、调休或带薪假。
- 取消整天请假会保留此前暂停记录，避免误补暂停期间的收入。
- 工作日/时间/工资配置保存当天会重算当天，界面已提示。月薪分母使用该日工资版本对应的当月计划工作日。
- 时间使用设备本地日历与时区，建议保持时区稳定；跨时区后历史日期和计算可能变化，尚未实现固定计薪时区。
- 各金额保留内部计算精度，展示两位小数，月累计与逐行四舍五入值相加可能略有差异。
- 小组件和 App 共享本地数据；不提供云同步、导入导出或历史恢复功能。
- 尚未制作上架所需 App Icon 与商店素材，也未声称已完成 App Store 上架准备。

## 文件

- `App/`：今日、月度、设置、共享存储。
- `Widget/`：WidgetKit 时间轴与小组件界面。
- `Sources/EarningsCore/`：工资版本、暂停/请假记录与计算逻辑。
- `Tests/EarningsCoreTests/`：XCTest 测试。
- `Scripts/verify-core.swift`：独立 Swift 回归检查。
- `Configuration/`：App Group 权限与 Info.plist。
