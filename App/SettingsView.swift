import SwiftUI
import EarningsCore

struct SettingsView: View {
    @EnvironmentObject private var model: EarningsModel
    @ViewState private var draft = WorkSettings()
    @ViewState private var salaryText = "10000"
    @ViewState private var fixedDaysText = "21.75"
    @ViewState private var useFixedDays = false
    @ViewState private var message: String?
    private let names = ["日", "一", "二", "三", "四", "五", "六"]

    private func timeBinding(_ keyPath: WritableKeyPath<WorkSettings, Int>) -> Binding<Date> {
        Binding(get: {
            Calendar.current.date(bySettingHour: draft[keyPath: keyPath] / 60, minute: draft[keyPath: keyPath] % 60, second: 0, of: .now)!
        }, set: { value in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: value)
            draft[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("工资 · 人民币") {
                    Picker("计薪方式", selection: $draft.mode) {
                        Text("月薪").tag(SalaryMode.monthly)
                        Text("日薪").tag(SalaryMode.daily)
                    }.pickerStyle(.segmented)
                    TextField(draft.mode == .monthly ? "月薪金额" : "日薪金额", text: $salaryText)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel(draft.mode == .monthly ? "月薪金额" : "日薪金额")
                    if draft.mode == .monthly {
                        Toggle("固定月计薪天数", isOn: $useFixedDays)
                        if useFixedDays {
                            TextField("例如 21.75", text: $fixedDaysText).keyboardType(.decimalPad)
                                .accessibilityLabel("固定计薪天数")
                        } else {
                            Text("日薪 = 月薪 ÷ 当月计划工作日。无薪请假不改变分母。")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                Section("工作时段") {
                    DatePicker("上班", selection: timeBinding(\.startMinute), displayedComponents: .hourAndMinute)
                    DatePicker("下班", selection: timeBinding(\.endMinute), displayedComponents: .hourAndMinute)
                    Toggle("午休不计薪", isOn: $draft.lunchEnabled)
                    if draft.lunchEnabled {
                        DatePicker("午休开始", selection: timeBinding(\.lunchStart), displayedComponents: .hourAndMinute)
                        DatePicker("午休结束", selection: timeBinding(\.lunchEnd), displayedComponents: .hourAndMinute)
                    }
                }
                Section("每周工作日") {
                    ForEach(1...7, id: \.self) { day in
                        Toggle("星期\(names[day - 1])", isOn: Binding(get: { draft.weekdays.contains(day) }, set: {
                            if $0 { draft.weekdays.insert(day) } else { draft.weekdays.remove(day) }
                        }))
                    }
                }
                Section {
                    Button("保存设置") { save() }.disabled(!model.loaded)
                    if let message { Text(message).font(.footnote).foregroundStyle(.secondary) }
                } footer: {
                    Text("更改从今天生效，会重新计算今天的收入，往日工资配置不变。不自动识别法定节假日、调休和税费；可在月度明细中标记无薪请假。暂不支持跨夜班次。")
                }
                Section("桌面小组件") {
                    Text("小组件显示今日收入、状态和更新时间。点击小组件进入 App 后可暂停或请假。iOS 不保证小组件按分钟或按秒刷新。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .onAppear {
                draft = model.data.settings(on: .now) ?? WorkSettings()
                salaryText = draft.salary.formatted(.number.grouping(.never))
                useFixedDays = draft.fixedDays != nil
                fixedDaysText = (draft.fixedDays ?? 21.75).formatted(.number.grouping(.never))
            }
        }
    }

    private func parse(_ text: String) -> Double? {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        return formatter.number(from: text)?.doubleValue
    }

    private func save() {
        guard let salary = parse(salaryText) else { message = "请输入有效工资金额。"; return }
        draft.salary = salary
        if useFixedDays {
            guard let days = parse(fixedDaysText) else { message = "请输入有效计薪天数。"; return }
            draft.fixedDays = days
        } else { draft.fixedDays = nil }
        if let error = draft.validationError { message = error; return }
        model.update { $0.save(draft, on: .now) }
        message = model.error == nil ? "已保存，从今天生效。" : "保存失败，请重试。"
    }
}
