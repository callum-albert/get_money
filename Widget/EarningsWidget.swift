import SwiftUI
import WidgetKit
import EarningsCore

struct EarningsEntry: TimelineEntry {
    let date: Date
    let result: DayEarnings
    let configured: Bool
    let failed: Bool
}

struct EarningsProvider: TimelineProvider {
    func placeholder(in context: Context) -> EarningsEntry { makeEntry(at: .now, data: EarningsData()) }
    func getSnapshot(in context: Context, completion: @escaping (EarningsEntry) -> Void) {
        do { completion(makeEntry(at: .now, data: try SharedStore.load())) }
        catch { completion(makeEntry(at: .now, data: EarningsData(), failed: true)) }
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<EarningsEntry>) -> Void) {
        let now = Date()
        do {
            let data = try SharedStore.load()
            // 五分钟一帧，工作边界另补精确帧；不依赖后台常驻。
            // 相比逐分钟的 241 帧，常规只生成 49 帧，降低扩展计算与编码开销。
            let horizon = now.addingTimeInterval(4 * 3600)
            var dates = Set((0...48).map { now.addingTimeInterval(Double($0) * 300) })
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: now)
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) {
                if tomorrow <= horizon { dates.insert(tomorrow) }
                for day in [today, tomorrow] {
                    if let settings = data.settings(on: day) {
                        for slot in EarningsEngine.intervals(on: day, settings: settings) {
                            for boundary in [slot.start, slot.end] where boundary > now && boundary <= horizon {
                                dates.insert(boundary)
                            }
                        }
                    }
                }
            }
            let entries = dates.sorted().map { makeEntry(at: $0, data: data) }
            completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(3 * 3600))))
        } catch {
            completion(Timeline(entries: [makeEntry(at: now, data: EarningsData(), failed: true)], policy: .after(now.addingTimeInterval(900))))
        }
    }
    private func makeEntry(at date: Date, data: EarningsData, failed: Bool = false) -> EarningsEntry {
        EarningsEntry(date: date, result: EarningsEngine.daily(on: date, asOf: date, data: data), configured: !data.versions.isEmpty, failed: failed)
    }
}

struct EarningsWidgetView: View {
    let entry: EarningsEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if entry.failed {
                Label("暂时无法读取", systemImage: "exclamationmark.triangle")
                Text("请解锁手机并打开 App 检查配置。")
                    .font(.caption).foregroundStyle(.secondary)
            } else if !entry.configured {
                Label("今日进账", systemImage: "yensign.circle")
                Text("点击设置工资").font(.headline)
                Text("让工作时间变成数字").font(.caption).foregroundStyle(.secondary)
            } else {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("今日已赚").font(.subheadline)
                        Text(entry.result.amount, format: .currency(code: "CNY").locale(Locale(identifier: "zh_CN")))
                            .font(.title.bold()).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
                        Text(entry.result.status).font(.caption).foregroundStyle(.secondary)
                    }
                    if family == .systemMedium {
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 8) {
                            Text("今日目标").font(.caption).foregroundStyle(.secondary)
                            Text(entry.result.target, format: .currency(code: "CNY").locale(Locale(identifier: "zh_CN")))
                                .font(.headline).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                            Text("已计薪 \(Int(entry.result.workedSeconds / 60)) 分钟").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
                ProgressView(value: entry.result.progress).tint(.teal)
                HStack(spacing: 3) {
                    Text("更新于")
                    Text(entry.date, style: .time)
                }.font(.caption2).foregroundStyle(.secondary)
            }
        }
        .containerBackground(.background, for: .widget)
        .widgetURL(URL(string: "todayearnings://today"))
    }
}

@main
struct EarningsWidget: Widget {
    let kind = "TodayEarningsWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EarningsProvider()) { entry in
            EarningsWidgetView(entry: entry)
        }
        .configurationDisplayName("今日进账")
        .description("查看按工作时段累积的今日收入。点击进入 App 暂停或请假。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
