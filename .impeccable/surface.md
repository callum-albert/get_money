# iPhone 主界面与桌面小组件

Mode: Operate。用户已同意按推荐方案直接实现，原生平台控件优先，不另阻塞功能开发。

## Direction contract
THESIS: 用工作日的时间刻度解释收入累积，拒绝游戏化金币和装饰性仪表盘。
OWN-WORLD: 采用日程时间条的精确密度，系统背景、系统文字、青绿色交互色；SF 字体、等宽金额，使用系统列表和导航。
STORY: 用户先看今日收入和当前状态，再暂停或标记整天请假；切换月度汇总查看逐日收入；设置可修改工作时段。
FIRST VIEWPORT: 原生大标题“今日进账”，收入、状态和有效工作时长，时间进度条在其下，暂停及请假按钮为主要操作。底部原生标签页连接今日、月度、设置。金额数字变化为唯一标志性动态，尊重减少动态效果。
FORM: 工作时间刻度，grounded candidate 7；seed:5c95c98d45f809e2。其余候选为工资单、月历、存折、打卡纸、日记、通勤时刻表。挑战方向的陌生隐喻不优于原生工作时间表达，取其对状态与密度的清晰要求而非外观。
FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## 验证边界
当前缺少 Xcode，无法获得真实模拟器画面。交付时明确声明原生 UI 未经运行验证，不能将源码检查称为视觉验收。
