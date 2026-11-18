# 今日进账 · 原生界面规范

## 平台与结构
- iPhone，iOS 17+，SwiftUI；WidgetKit 支持 systemSmall / systemMedium。
- 原生 TabView：今日 / 月度 / 设置；每页使用 NavigationStack 与系统大标题。
- 操作与设置采用 List / Form，确认整天请假使用 confirmationDialog。

## 类型与颜色
- 使用系统文字样式及 Dynamic Type；金额使用 largeTitle.bold / title.bold 与 monospacedDigit。
- 系统背景、primary / secondary 文字确保深浅模式语义适配。
- teal 为唯一交互与收入进度强调色；整天请假为系统 destructive 语义。
- 不使用自定义阴影、装饰纹理或图像资产；图标全部 SF Symbols。

## 信息与动作
- 今日收入 → 状态 → 收入进度及计薪分钟 → 当日操作。
- 小组件中给出更新时间，不暗示真正的后台秒刷。
- 工资未设置、共享容器读取失败、休息日、午休、请假、暂停和下班分别有明确状态。
- 为节能不添加金额过渡动画；仅今日页选中且 App 活跃时按秒刷新，月度页使用按需快照。
- 月度日期列表提供无薪请假补记；暂停与请假不直接放在小组件中，点击进入 App 完成。

## 验收状态
源码结构检查完成，无位图资产。尚无完整 Xcode，未获得 iPhone 模拟器或真机截图；深浅色、辅助功能字号、小组件裁切和 VoiceOver 均仍需原生运行验收，不能视为已经通过。
