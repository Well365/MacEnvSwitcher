
import SwiftUI

@main
struct MacEnvSwitcherApp: App {
    @ObservedObject private var languageManager = LanguageManager.shared
    @AppStorage("setupCompleted") private var setupCompleted = false
    @AppStorage("checkOnStartup") private var checkOnStartup = true
    @State private var showingSetupWizard = false
    
    init() {
        // 设置应用语言
        applyLanguageSettings()
        
        // 恢复系统环境配置
        restoreSystemEnvironment()
    }
    
    var body: some Scene {
        WindowGroup {
            MainAppView(showingSetupWizard: $showingSetupWizard)
                .frame(
                    minWidth: 900, 
                    idealWidth: 1100, 
                    maxWidth: .infinity,
                    minHeight: 700, 
                    idealHeight: 800, 
                    maxHeight: .infinity
                )
                .environment(\.locale, currentLocale)
                .onAppear {
                    // 首次启动时强制显示设置向导
                    if !setupCompleted {
                        // 短暂延迟以确保窗口已显示
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.showingSetupWizard = true
                        }
                    } else if checkOnStartup {
                        // 非首次启动但需要检查
                        checkRequiredTools()
                    }
                }
                .sheet(isPresented: $showingSetupWizard) {
                    SetupWizardView()
                        .onDisappear {
                            setupCompleted = true
                        }
                }
        }
        .commands {
            CommandGroup(replacing: .help) {
                Button("设置向导") {
                    showingSetupWizard = true
                }
                .keyboardShortcut("?", modifiers: [.command])
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
    
    private func checkRequiredTools() {
        DispatchQueue.global(qos: .userInitiated).async {
            let detectors = Detectors()
            
            // 检查必需工具
            let xcodeCheck = detectors.check(.xcode)
            let cltCheck = detectors.check(.clt)
            let brewCheck = detectors.check(.brew)
            let zshCheck = detectors.check(.ohMyBash)
            let asdfCheck = detectors.check(.asdf)
            
            // 如果有任何工具未安装，显示设置向导
            let allInstalled = xcodeCheck.ok && cltCheck.ok && brewCheck.ok && zshCheck.ok && asdfCheck.ok
            
            if !allInstalled {
                DispatchQueue.main.async {
                    showingSetupWizard = true
                }
            }
        }
    }
}

// 主应用视图
struct MainAppView: View {
    @Binding var showingSetupWizard: Bool
    @State private var selectedTab: Tab = .languages
    @AppStorage("checkOnStartup") private var checkOnStartup = true
    
    enum Tab {
        case languages
        case profiles
        case settings
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // 侧边栏
            VStack(spacing: 0) {
                // 标题
                Text("MacEnvSwitcher")
                    .font(.headline)
                    .padding()
                
                Divider()
                
                List {
                    Section(tr("Main Features")) {
                        Button(action: { selectedTab = .languages }) {
                            Label(tr("Language Management"), systemImage: "terminal.fill")
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)
                        .background(selectedTab == .languages ? Color.accentColor.opacity(0.2) : Color.clear)
                        .cornerRadius(6)
                        
                        Button(action: { selectedTab = .profiles }) {
                            Label(tr("Environment Profiles"), systemImage: "doc.text.fill")
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)
                        .background(selectedTab == .profiles ? Color.accentColor.opacity(0.2) : Color.clear)
                        .cornerRadius(6)
                    }
                    
                    Section(tr("System")) {
                        Button(action: { selectedTab = .settings }) {
                            Label(tr("Settings"), systemImage: "gear")
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)
                        .background(selectedTab == .settings ? Color.accentColor.opacity(0.2) : Color.clear)
                        .cornerRadius(6)
                    }
                }
                .listStyle(SidebarListStyle())
            }
            .frame(width: 240)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // 主内容区域
            Group {
                switch selectedTab {
                case .languages:
                    LanguageManagementView()
                case .profiles:
                    EnvironmentManagerView()
                case .settings:
                    SettingsView(showingSetupWizard: $showingSetupWizard, checkOnStartup: $checkOnStartup)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// 设置视图
struct SettingsView: View {
    @Binding var showingSetupWizard: Bool
    @Binding var checkOnStartup: Bool
    
    var body: some View {
        Form {
            Section("启动设置") {
                Toggle("启动时检查必需工具", isOn: $checkOnStartup)
                    .help("每次启动应用时检查 Xcode、Homebrew、asdf 等工具是否已安装")
                
                Button("运行设置向导") {
                    showingSetupWizard = true
                }
                .help("手动运行设置向导，检查并安装必需工具")
            }
            
            Section("关于") {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("4.0.0")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("描述")
                    Spacer()
                    Text("macOS 开发环境管理工具")
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: 600)
        .padding()
    }
}
