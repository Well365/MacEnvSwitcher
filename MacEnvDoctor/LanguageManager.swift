import SwiftUI
import Foundation

// 语言管理器 - 处理应用内语言切换
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @Published var currentLanguage: AppLanguage = .systemDefault {
        didSet {
            saveLanguagePreference()
            updateAppLanguage()
        }
    }
    
    private init() {
        loadLanguagePreference()
    }
    
    // 应用支持的语言
    enum AppLanguage: String, CaseIterable, Identifiable {
        case systemDefault = "system"
        case english = "en"
        case chinese = "zh-Hans"
        case japanese = "ja"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .systemDefault:
                return NSLocalizedString("System Default", comment: "")
            case .english:
                return "English"
            case .chinese:
                return "简体中文"
            case .japanese:
                return "日本語"
            }
        }
        
        var localeIdentifier: String? {
            switch self {
            case .systemDefault:
                return nil
            case .english:
                return "en"
            case .chinese:
                return "zh-Hans"
            case .japanese:
                return "ja"
            }
        }
    }
    
    private func saveLanguagePreference() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: "AppLanguage")
    }
    
    private func loadLanguagePreference() {
        if let savedLanguage = UserDefaults.standard.string(forKey: "AppLanguage"),
           let language = AppLanguage(rawValue: savedLanguage) {
            currentLanguage = language
        }
    }
    
    private func updateAppLanguage() {
        // 更新 UserDefaults 的语言设置
        if let localeIdentifier = currentLanguage.localeIdentifier {
            UserDefaults.standard.set([localeIdentifier], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
        
        // 通知应用更新语言
        NotificationCenter.default.post(name: .languageChanged, object: nil)
    }
    
    // 获取本地化字符串
    func localizedString(for key: String) -> String {
        guard let localeIdentifier = currentLanguage.localeIdentifier,
              let path = Bundle.main.path(forResource: localeIdentifier, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(key, comment: "")
        }
        
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
}

// 语言变更通知
extension Notification.Name {
    static let languageChanged = Notification.Name("LanguageChanged")
}

// 语言选择器视图
struct LanguagePickerView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "globe")
                .foregroundColor(.secondary)
            
            Picker(tr("Language"), selection: $languageManager.currentLanguage) {
                ForEach(LanguageManager.AppLanguage.allCases) { language in
                    Text(language.displayName)
                        .tag(language)
                }
            }
            .pickerStyle(.menu)
            .frame(minWidth: 120)
        }
    }
}