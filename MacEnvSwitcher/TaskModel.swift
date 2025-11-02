
import SwiftUI

func tr(_ key: String) -> String {
    let languageManager = LanguageManager.shared
    return languageManager.localizedString(for: key)
}

enum TaskID: CaseIterable {
    case clt, brew, iterm2, ohMyBash, python3, ruby, fastlane, xcode, asdf,
         nodejs, golang, java, pnpm, yarn, maven, gradle, pythonAsdf, rust, jabba
    
    var displayName: String {
        switch self {
        case .clt: return tr("Xcode Command Line Tools")
        case .brew: return "Homebrew"
        case .iterm2: return "iTerm2"
        case .ohMyBash: return "oh-my-zsh"
        case .python3: return "Python 3"
        case .ruby: return "Ruby"
        case .fastlane: return "fastlane"
        case .xcode: return "Xcode"
        case .asdf: return tr("asdf (version manager)")
        case .nodejs: return tr("Node.js (via asdf)")
        case .golang: return tr("Go (via asdf)")
        case .java: return tr("Java (via asdf)")
        case .pnpm: return tr("pnpm (via asdf)")
        case .yarn: return tr("yarn (via asdf)")
        case .maven: return tr("Maven (via asdf)")
        case .gradle: return tr("Gradle (via asdf)")
        case .pythonAsdf: return tr("Python (via asdf)")
        case .rust: return tr("Rust (via asdf)")
        case .jabba: return tr("jabba (Java manager)")
        }
    }
    
    struct TaskState {
        var installed: Bool? = nil
        var isBusy: Bool = false
        var isSkipped: Bool = false
        var log: String = ""
        var tip: String? = nil
        var supportsVersioning: Bool = false
    }
    
    final class BootstrapViewModel: ObservableObject {
        @Published var state: [TaskID: TaskState] = {
            var dict: [TaskID: TaskState] = [:]
            for t in TaskID.allCases {
                var st = TaskState()
                switch t {
                case .nodejs, .golang, .java, .pnpm, .yarn, .maven, .gradle, .pythonAsdf, .rust:
                    st.supportsVersioning = true
                default: break
                }
                dict[t] = st
            }
            return dict
        }()
        
        @Published var lastReportPath: String? = nil
        
        // profiles & groups
        @Published var profiles: [EnvironmentProfile] = ProfilesStore.loadProfiles()
        @Published var groups: [ProfileGroup] = ProfilesStore.loadGroups()
        @Published var selectedProfile: EnvironmentProfile? = nil
        @Published var selectedGroup: ProfileGroup? = nil
        @Published var showEditor: Bool = false
        @Published var showEnvironmentManager: Bool = false
        @Published var currentActiveProfile: EnvironmentProfile? = ProfilesStore.getCurrentActiveProfile()
        @Published var isSwitchingEnvironment: Bool = false
        
        private let detectors = Detectors()
        private let installers = Installers()
        
        var summaryLine: String {
            let done = TaskID.allCases.filter { (state[$0]?.installed ?? false) }.count
            return tr("Ready ") + "\(done)/\(TaskID.allCases.count)"
        }
        
        // MARK: - Actions
        func toggleSkip(_ t: TaskID) { state[t]?.isSkipped.toggle(); objectWillChange.send() }
        func runFullCheck() { for t in TaskID.allCases { check(t) } }
        
        func check(_ t: TaskID) {
            state[t]?.isBusy = true; state[t]?.tip = nil; state[t]?.log = ""
            objectWillChange.send()
            DispatchQueue.global().async {
                let result = self.detectors.check(t)
                DispatchQueue.main.async {
                    self.state[t]?.installed = result.ok
                    self.state[t]?.isBusy = false
                    self.state[t]?.log = result.log
                    self.state[t]?.tip = result.tip
                }
            }
        }
        
        func install(_ t: TaskID, autoYes: Bool) {
            if state[t]?.isSkipped == true { return }
            state[t]?.isBusy = true; state[t]?.tip = nil; state[t]?.log = ""
            objectWillChange.send()
            DispatchQueue.global().async {
                let (_, log, tip) = self.installers.install(t, autoYes: autoYes)
                let re = self.detectors.check(t)
                DispatchQueue.main.async {
                    self.state[t]?.installed = re.ok
                    self.state[t]?.isBusy = false
                    self.state[t]?.log = log + "\n--- " + tr("Check Result: ") + (re.ok ? tr("Installed") : tr("Not Ready")) + "\n" + re.log
                    self.state[t]?.tip = tip ?? re.tip
                }
            }
        }
        
        func installMissing(autoYes: Bool) {
            for t in TaskID.allCases where (state[t]?.isSkipped != true) {
                if state[t]?.installed == false || state[t]?.installed == nil {
                    install(t, autoYes: autoYes)
                }
            }
        }
        
        func openXcodeAppStore() { installers.openXcodeAppStore() }
        
        // MARK: - Version management
        func installLatest(_ t: TaskID) { installers.installLatest(t) { self.after($0, $1, $2, t) } }
        func listVersions(_ t: TaskID) { installers.listVersions(t) { self.after($0, $1, $2, t) } }
        func installVersion(_ t: TaskID, version: String) { installers.installVersion(t, version: version) { self.after($0, $1, $2, t) } }
        func setDefault(_ t: TaskID, version: String) { installers.setDefault(t, version: version) { self.after($0, $1, $2, t) } }
        private func after(_ ok: Bool, _ log: String, _ tip: String?, _ t: TaskID) {
            let re = self.detectors.check(t)
            DispatchQueue.main.async {
                self.state[t]?.installed = re.ok
                self.state[t]?.isBusy = false
                self.state[t]?.log = log + "\n--- " + tr("Check Result: ") + (re.ok ? tr("Installed") : tr("Not Ready")) + "\n" + re.log
                self.state[t]?.tip = tip ?? re.tip
            }
        }
        
        // MARK: - Reports
        func saveReportJSON() {
            var report = Report(items: [])
            for t in TaskID.allCases {
                let st = state[t] ?? TaskState()
                report.items.append(.init(name: t.displayName, installed: st.installed ?? false, skipped: st.isSkipped, note: st.tip))
            }
            let p = report.save()
            DispatchQueue.main.async { self.lastReportPath = p }
        }
        
        // MARK: - Profiles & Groups helpers
        func reloadProfiles() { 
            profiles = ProfilesStore.loadProfiles()
            currentActiveProfile = ProfilesStore.getCurrentActiveProfile()
        }
        func exportProfilesSample() { ProfilesStore.saveProfiles(ProfilesStore.builtinProfiles()); reloadProfiles() }
        func reloadGroups() { groups = ProfilesStore.loadGroups() }
        func exportGroupsSample() { ProfilesStore.saveGroups(ProfilesStore.builtinGroups()); reloadGroups() }
        
        func applySelectedProfile() {
            guard let profile = selectedProfile else { return }
            DispatchQueue.global().async {
                let (_, log, tip) = self.installers.apply(profile: profile)
                DispatchQueue.main.async {
                    self.state[.asdf]?.log = (self.state[.asdf]?.log ?? "") + "\\n" + log
                    self.state[.asdf]?.tip = tip
                    self.currentActiveProfile = ProfilesStore.getCurrentActiveProfile()
                    // 重新加载配置文件以确保界面同步
                    self.reloadProfiles()
                    // 执行全面检查
                    self.runFullCheck()
                    // 发送通知以确保界面更新
                    self.objectWillChange.send()
                }
            }
        }
        func applySelectedGroup() {
            guard let g = selectedGroup else { return }
            let nameSet = Set(g.profileNames)
            let used = profiles.filter{ nameSet.contains($0.name) }
            // Merge profiles by plugin key, last one wins
            var merged = EnvironmentProfile(name: g.name + " (merged)", versions: [:])
            for p in used { for (k,v) in p.versions { merged.versions[k] = v } }
            DispatchQueue.global().async {
                let (_, log, tip) = self.installers.apply(profile: merged)
                DispatchQueue.main.async {
                    self.state[.asdf]?.log = (self.state[.asdf]?.log ?? "") + "\\n[Group] " + g.name + "\\n" + log
                    self.state[.asdf]?.tip = tip
                    self.currentActiveProfile = ProfilesStore.getCurrentActiveProfile()
                    // 重新加载配置文件以确保界面同步
                    self.reloadProfiles()
                    // 执行全面检查
                    self.runFullCheck()
                    // 发送通知以确保界面更新
                    self.objectWillChange.send()
                }
            }
        }
        
        // MARK: - Environment Management
        func switchToEnvironment(_ profile: EnvironmentProfile) {
            isSwitchingEnvironment = true
            
            installers.switchToEnvironment(profile) { [weak self] ok, log, tip in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    self.isSwitchingEnvironment = false
                    
                    self.state[.asdf]?.log = (self.state[.asdf]?.log ?? "") + "\n[Switch Environment]\n" + log
                    self.state[.asdf]?.tip = tip
                    self.currentActiveProfile = ProfilesStore.getCurrentActiveProfile()
                    
                    // 重新加载配置文件以确保界面同步
                    self.reloadProfiles()
                    
                    // 执行全面检查以更新所有状态
                    self.runFullCheck()
                    
                    // 重新加载版本管理器中的可用版本
                    self.reloadVersionManager()
                    
                    // 发送通知以确保界面更新
                    self.objectWillChange.send()
                    
                    // 显示成功或失败消息
                    if ok {
                        self.showEnvironmentSwitchSuccess(profile: profile)
                    } else {
                        self.showEnvironmentSwitchFailure(profile: profile, log: log)
                    }
                }
            }
        }
        
        // 重新加载版本管理器
        private func reloadVersionManager() {
            let versionManager = VersionManager.shared
            // 清除缓存并重新加载所有任务的版本信息
            for task in TaskID.allCases {
                if task == .nodejs || task == .pythonAsdf || task == .ruby || task == .golang || task == .java || task == .rust {
                    versionManager.loadAvailableVersions(for: task)
                }
            }
        }
        
        // 显示环境切换成功消息
        private func showEnvironmentSwitchSuccess(profile: EnvironmentProfile) {
            // 这里可以添加通知或其他UI反馈
            print("✅ Successfully switched to environment: \(profile.name)")
            print("ℹ️ 提示: 请在终端中运行 'source ~/.zshrc' 或重新打开终端以使配置生效")
            
            // 更新终端标题（如果支持）
            let script = """
        echo "\\033]0;MacEnvSwitcher - \(profile.name)\\007"
        """
            _ = Shell.run(script)
            
            // 发送通知以显示提示
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("EnvironmentSwitchSuccess"),
                    object: profile,
                    userInfo: [
                        "message": tr("Environment switched successfully! Please run 'source ~/.zshrc' in your terminal or open a new terminal window for the changes to take effect.")
                    ]
                )
            }
        }
        
        // 显示环境切换失败消息
        private func showEnvironmentSwitchFailure(profile: EnvironmentProfile, log: String) {
            print("⚠️ Environment switch failed or has warnings: \(profile.name)")
            print("⚠️ Log: \(log)")
            
            // 发送通知以显示错误提示
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("EnvironmentSwitchFailure"),
                    object: profile,
                    userInfo: [
                        "message": tr("Environment switch completed with warnings. Some versions may not be set correctly. Please check the logs for details."),
                        "log": log
                    ]
                )
            }
        }
        
        func deactivateCurrentEnvironment() {
            let (_, log, tip) = installers.deactivateCurrentEnvironment()
            state[.asdf]?.log = (state[.asdf]?.log ?? "") + "\n" + log
            state[.asdf]?.tip = tip
            currentActiveProfile = nil
            // 重新加载配置文件以确保界面同步
            reloadProfiles()
            // 执行全面检查
            runFullCheck()
            // 发送通知以确保界面更新
            objectWillChange.send()
        }
        
        func addEnvironment(_ profile: EnvironmentProfile) {
            ProfilesStore.addProfile(profile)
            reloadProfiles()
        }
        
        func deleteEnvironment(_ profileName: String) {
            ProfilesStore.deleteProfile(profileName)
            reloadProfiles()
        }
        
        func updateEnvironment(_ profile: EnvironmentProfile) {
            ProfilesStore.updateProfile(profile)
            reloadProfiles()
        }
    }
}
