import SwiftUI
import EarningsCore

struct TodayView: View {
    let isSelected: Bool
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var model: EarningsModel
    @ViewState private var confirmLeave = false

    var body: some View {
        NavigationStack {
            TimelineView(.animation(minimumInterval: 1, paused: !isSelected || scenePhase != .active)) { context in
                let now = context.date
                let result = EarningsEngine.daily(on: now, asOf: now, data: model.data)
                List {
                    if !model.loaded {
                        ContentUnavailableView("无法读取数据", systemImage: "exclamationmark.icloud", description: Text("请检查 App Group 配置，使用提示中的重试读取。"))
                    } else if model.data.versions.isEmpty {
                        ContentUnavailableView("让工作时间变成数字", systemImage: "yensign.circle", description: Text("先到“设置”填写工资并保存，再将“今日进账”添加到桌面。"))
                    } else {
                        Section {
                            VStack(alignment: .leading, spacing: 14) {
                                Text(money(result.amount))
                                    .font(.largeTitle.bold()).monospacedDigit()
                                    .accessibilityLabel("今日已赚 \(money(result.amount))")
                                Label(result.status, systemImage: result.isLeave ? "calendar.badge.minus" : result.isPaused ? "pause.circle" : "clock")
                                    .foregroundStyle(.secondary)
                                ProgressView(value: result.progress).tint(.teal)
                                    .accessibilityLabel("今日收入进度")
                                Text("今日目标 \(money(result.target)) · 已计薪 \(Int(result.workedSeconds / 60)) 分钟")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }.padding(.vertical, 12)
                        }
                        Section("今日安排") {
                            if let settings = model.data.settings(on: now) {
                                LabeledContent("工作时间", value: "\(clock(settings.startMinute))–\(clock(settings.endMinute))")
                                if settings.lunchEnabled {
                                    LabeledContent("午休不计薪", value: "\(clock(settings.lunchStart))–\(clock(settings.lunchEnd))")
                                }
                            }
                            Button {
                                model.update { $0.togglePause(at: now) }
                            } label: {
                                Label(result.isPaused ? "继续计薪" : "暂停计薪", systemImage: result.isPaused ? "play.fill" : "pause.fill")
                                    .frame(minHeight: 32)
                            }
                            .disabled(result.isLeave || result.target == 0 || ["未开工", "已下班"].contains(result.status))
                            Button(role: result.isLeave ? nil : .destructive) {
                                if result.isLeave { model.update { $0.setLeave(false, on: now) } }
                                else { confirmLeave = true }
                            } label: {
                                Label(result.isLeave ? "取消今天请假" : "今天整天请假", systemImage: "calendar.badge.minus")
                                    .frame(minHeight: 32)
                            }
                        }
                        Section {
                            Text("暂停只扣除暂停期间的工作时长，恢复后不会补算。整天请假将今日收入记为 0。金额仅为工资估算。")
                            Text("添加小组件：长按桌面 → 编辑 → 添加小组件 → 今日进账。桌面刷新由系统控制，App 内每秒更新。")
                        }.font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .confirmationDialog("将今天标记为整天无薪请假？", isPresented: $confirmLeave, titleVisibility: .visible) {
                    Button("整天请假，今日收入归零", role: .destructive) { model.update { $0.setLeave(true, on: now) } }
                } message: { Text("可取消请假；已有暂停记录会保留。") }
            }
            .navigationTitle("今日进账")
        }
    }
}
