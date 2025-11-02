
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
                        .frame(minWidth: 850, idealWidth: 1000, minHeight: 550, idealHeight: 600)
                        .onDisappear {
                            setupCompleted = true
                        }
                }
        }
        .commands {
            CommandGroup(replacing: .help) {
                Button(tr("Basic Software Check")) {
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
        case setupWizard
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
                        
                        Button(action: { selectedTab = .setupWizard }) {
                            Label(tr("Basic Software Check"), systemImage: "checkmark.shield.fill")
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)
                        .background(selectedTab == .setupWizard ? Color.accentColor.opacity(0.2) : Color.clear)
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
                case .setupWizard:
                    SetupWizardView(showContinueButton: false)
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
        ScrollView {
            VStack(spacing: 24) {
                // 标题
                HStack {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tr("Settings"))
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(tr("Configure application preferences"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                
                Divider()
                
                // 语言设置卡片
                SettingCard(
                    icon: "globe",
                    iconColor: .blue,
                    title: tr("Language Settings")
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(tr("Display Language"))
                                .font(.headline)
                            
                            Spacer()
                            
                            Picker("", selection: $languageManager.currentLanguage) {
                                ForEach(languageManager.availableLanguages) { language in
                                    Text(language.displayName).tag(language)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 150)
                        }
                        
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.orange)
                                .font(.caption)
                            
                            Text(tr("Language changes will take effect after restarting the app"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                // 启动设置卡片
                SettingCard(
                    icon: "power",
                    iconColor: .green,
                    title: tr("Startup Settings")
                ) {
                    VStack(spacing: 16) {
                        Toggle(isOn: $checkOnStartup) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tr("Check tools on startup"))
                                    .font(.headline)
                                
                                Text(tr("Check if Xcode, Homebrew, asdf are installed on app launch"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle())
                        
                    }
                }
                
                // 关于卡片
                SettingCard(
                    icon: "info.circle",
                    iconColor: .purple,
                    title: tr("About")
                ) {
                    VStack(spacing: 12) {
                        InfoRow(label: tr("Application Name"), value: "MacEnvSwitcher")
                        Divider()
                        InfoRow(label: tr("Version"), value: "4.0.0")
                        Divider()
                        InfoRow(label: tr("Description"), value: tr("macOS Development Environment Manager"))
                        Divider()
                        
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(.green)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tr("Development Tools"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("Xcode • Homebrew • asdf • oh-my-zsh")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// 设置卡片组件
struct SettingCard<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let content: Content
    
    init(icon: String, iconColor: Color, title: String, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(iconColor)
                }
                
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            content
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// 信息行组件
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

