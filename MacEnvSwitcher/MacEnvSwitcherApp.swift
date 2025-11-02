
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
    @ObservedObject private var languageManager = LanguageManager.shared
    
    var body: some View {
        Form {
            Section(tr("Language Settings")) {
                Picker(tr("Display Language"), selection: $languageManager.currentLanguage) {
                    ForEach(languageManager.availableLanguages) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.menu)
                
                Text(tr("Language changes will take effect after restarting the app"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(tr("Startup Settings")) {
                Toggle(tr("Check tools on startup"), isOn: $checkOnStartup)
                    .help(tr("Check if Xcode, Homebrew, asdf are installed on app launch"))
                
                Button(tr("Run Setup Wizard")) {
                    showingSetupWizard = true
                }
                .help(tr("Manually run setup wizard to check and install required tools"))
            }
            
            Section(tr("About")) {
                HStack {
                    Text(tr("Version"))
                    Spacer()
                    Text("4.0.0")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text(tr("Description"))
                    Spacer()
                    Text(tr("macOS Development Environment Manager"))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: 600)
        .padding()
    }
}
