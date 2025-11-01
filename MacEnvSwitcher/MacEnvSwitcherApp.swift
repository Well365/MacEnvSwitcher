
import SwiftUI
@main
struct MacEnvSwitcherApp: App {
    @ObservedObject private var languageManager = LanguageManager.shared
    
    init() {
        // 设置应用语言
        applyLanguageSettings()
        
        // 恢复系统环境配置
        restoreSystemEnvironment()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
                .environment(\.locale, currentLocale)
                .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
                    // 语言变更时强制重绘视图
                }
        }
    }
    
    private var currentLocale: Locale {
        if let localeIdentifier = languageManager.currentLanguage.localeIdentifier {
            return Locale(identifier: localeIdentifier)
        }
        return Locale.current
    }
    
    private func applyLanguageSettings() {
        if let localeIdentifier = languageManager.currentLanguage.localeIdentifier {
            UserDefaults.standard.set([localeIdentifier], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
        }
    }
    
    private func restoreSystemEnvironment() {
        // 在后台线程恢复系统配置，避免阻塞应用启动
        DispatchQueue.global(qos: .background).async {
            ProfilesStore.restoreSystemConfiguration()
        }
    }
}
