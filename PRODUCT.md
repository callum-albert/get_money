# 今日进账

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Stack
SwiftUI + WidgetKit，用户已确认。原生 iPhone App 作为小组件设置与汇总入口。

## Users
希望随时查看当日工资累积的上班族。

## Product Purpose
优先通过桌面小组件查看今日已赚，按工作时段计算，提供日薪/月薪设置、暂停、请假和月度汇总。

## Capabilities and Constraints
- 用户确认默认 09:00–18:00，可自定义。
- App 内每秒重算；WidgetKit 时间轴更新受系统调度，不能承诺秒刷。
- 本地保存，不注册、不联网。
- 实现默认：人民币、周一到周五、12:00–13:00 午休（可关闭）；月薪按当月计划工作日或固定天数折算。以上默认并非用户的个人工资事实。
- 当天配置修改影响当天与未来，不重写往日工资版本。请假默认无薪，金额为估算而非工资单。
- 当前只有 Command Line Tools，原生构建与视觉验证需要完整 Xcode。
