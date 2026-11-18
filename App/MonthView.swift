import SwiftUI
import EarningsCore

struct MonthView: View {
    @EnvironmentObject private var model: EarningsModel
    @ViewState private var selectedMonth = Date.now
    @ViewState private var pendingDay: Date?
    @ViewState private var snapshotDate = Date.now
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            let rows = EarningsEngine.month(containing: selectedMonth, asOf: snapshotDate, data: model.data)
                List {
                    Section {
                        HStack {
                            Button { move(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel("上个月")
                            Spacer()
                            Text(selectedMonth.formatted(.dateTime.year().month(.wide))).font(.headline)
                            Spacer()
                            Button { move(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                                .accessibilityLabel("下个月")
                                .disabled(Calendar.current.isDate(selectedMonth, equalTo: snapshotDate, toGranularity: .month))
                        }.buttonStyle(.borderless)
                        LabeledContent("累计已赚", value: money(rows.reduce(0) { $0 + $1.amount })).monospacedDigit()
                        LabeledContent("请假天数", value: "\(rows.filter(\.isLeave).count) 天")
                    }
                    if rows.allSatisfy({ $0.status == "未设置" }) {
                        ContentUnavailableView("这个月还没有计薪记录", systemImage: "calendar", description: Text("工资从首次保存设置当天开始记录，不推算此前收入。"))
                    } else {
                        Section {
                            ForEach(rows.reversed(), id: \.date) { row in
                                Button { pendingDay = row.date } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(row.date.formatted(.dateTime.month().day().weekday())).foregroundStyle(.primary)
                                            Text(row.isLeave ? "整天请假" : row.target == 0 ? row.status : "计薪 \(Int(row.workedSeconds / 60)) 分钟")
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(money(row.amount)).monospacedDigit().foregroundStyle(.primary)
                                    }.frame(minHeight: 44)
                                }.disabled(row.status == "未设置")
                            }
                        } header: { Text("每日明细") } footer: {
                            Text("点击日期可标记或取消整天无薪请假。累计金额由未四舍五入的明细相加后显示，因此可能与逐行显示相加相差几分钱。")
                        }
                    }
                }
                .confirmationDialog("修改整天请假记录", isPresented: Binding(get: { pendingDay != nil }, set: { if !$0 { pendingDay = nil } }), titleVisibility: .visible) {
                    if let day = pendingDay {
                        let leave = model.data.records[EarningsEngine.dayKey(day)]?.isLeave ?? false
                        Button(leave ? "取消整天请假" : "标记整天无薪请假", role: leave ? nil : .destructive) {
                            model.update { $0.setLeave(!leave, on: day) }; pendingDay = nil
                        }
                    }
                } message: { Text("只修改选定日期，不影响其他工作日。") }
            .navigationTitle("月度汇总")
            .onAppear { snapshotDate = .now }
            .onChange(of: scenePhase) { _, phase in if phase == .active { snapshotDate = .now } }
            .refreshable { snapshotDate = .now }
        }
    }

    private func move(_ delta: Int) {
        if let month = Calendar.current.dateInterval(of: .month, for: selectedMonth)?.start,
           let date = Calendar.current.date(byAdding: .month, value: delta, to: month) { selectedMonth = date }
    }
}
