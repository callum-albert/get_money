import SwiftUI
import WidgetKit
import EarningsCore

@MainActor
final class EarningsModel: ObservableObject {
    @Published private(set) var data = EarningsData()
    @Published var error: String?
    @Published private(set) var loaded = false

    init() { reload() }
    func reload() {
        do { data = try SharedStore.load(); loaded = true; error = nil }
        catch { self.error = "读取失败：\(error.localizedDescription)。未覆盖原有数据，请检查签名配置后重试。"; loaded = false }
    }
    func update(_ mutation: (inout EarningsData) -> Void) {
        guard loaded else { return }
        var next = data
        mutation(&next)
        do {
            try SharedStore.save(next)
            data = next
            WidgetCenter.shared.reloadAllTimelines()
        } catch { self.error = "保存失败：\(error.localizedDescription)。本次更改未保存，请重试。" }
    }
}

@main
struct TodayEarningsApp: App {
    @StateObject private var model = EarningsModel()
    @Environment(\.scenePhase) private var scenePhase
    @ViewState private var selectedTab = 0
    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                TodayView(isSelected: selectedTab == 0).tabItem { Label("今日", systemImage: "sun.max") }.tag(0)
                MonthView().tabItem { Label("月度", systemImage: "calendar") }.tag(1)
                SettingsView().tabItem { Label("设置", systemImage: "slider.horizontal.3") }.tag(2)
            }
            .tint(.teal)
            .environmentObject(model)
            .alert("数据未能保存或读取", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                Button("重试读取") { model.reload() }
                Button("关闭", role: .cancel) { model.error = nil }
            } message: { Text(model.error ?? "") }
            .onChange(of: scenePhase) { _, phase in if phase == .active { model.reload() } }
        }
    }
}

func money(_ amount: Double) -> String {
    amount.formatted(.currency(code: "CNY").locale(Locale(identifier: "zh_CN")))
}

func clock(_ minutes: Int) -> String { String(format: "%02d:%02d", minutes / 60, minutes % 60) }
