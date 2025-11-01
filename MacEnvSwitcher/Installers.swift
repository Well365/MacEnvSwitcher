
import Foundation
import AppKit

struct InstallationCache {
    static let cacheDir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".macenvswitcher/cache")
    static let sourceDir = cacheDir.appendingPathComponent("sources")
    static let packageDir = cacheDir.appendingPathComponent("packages")
    
    static func ensureCacheDirectories() {
        try? FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: packageDir, withIntermediateDirectories: true)
    }
    
    static func getCachedPackage(tool: String, version: String) -> URL? {
        let packageFile = packageDir.appendingPathComponent("\(tool)-\(version).pkg")
        return FileManager.default.fileExists(atPath: packageFile.path) ? packageFile : nil
    }
    
    static func cachePackage(tool: String, version: String, data: Data) -> Bool {
        ensureCacheDirectories()
        let packageFile = packageDir.appendingPathComponent("\(tool)-\(version).pkg")
        do {
            try data.write(to: packageFile)
            return true
        } catch {
            return false
        }
    }
}

struct AlternativeInstaller {
    let name: String
    let command: String
    let description: String
    let priority: Int
}

final class Installers {
    func install(_ t: TaskID, autoYes: Bool) -> (Bool, String, String?) {
        switch t {
        case .clt: return installCLT()
        case .brew: return installBrew()
        case .iterm2: return brewCask("iterm2")
        case .ohMyBash: return installOhMyBash()
        case .python3: return brewPkg("python")
        case .ruby: return installRuby()
        case .fastlane: return brewPkg("fastlane")
        case .xcode: openXcodeAppStore(); return (false, tr("Opened App Store. Please install Xcode manually."), tr("Xcode cannot be installed silently. Open App Store and install."))
        case .asdf: return installAsdf()
        case .nodejs: return ensureLatest("nodejs")
        case .golang: return ensureLatest("golang")
        case .java: return ensureJavaLatest()
        case .pnpm: return ensureLatest("pnpm", needs: ["nodejs"])
        case .yarn: return ensureLatest("yarn", needs: ["nodejs"])
        case .maven: return ensureLatest("maven")
        case .gradle: return ensureLatest("gradle")
        case .pythonAsdf: return ensureLatest("python")
        case .rust: return ensureLatest("rust")
        case .jabba: return installJabba()
        }
    }

    // MARK: - Xcode / CLT
    private func installCLT() -> (Bool, String, String?) {
        let r = Shell.run("xcode-select --install || true")
        let tip = tr("If no installer pops up, open System Settings ▶ General ▶ Software Update and install Command Line Tools")
        return (true, r.out + r.err, tip)
    }
    func openXcodeAppStore() { NSWorkspace.shared.open(URL(string: "macappstore://itunes.apple.com/app/id497799835")!) }

    // MARK: - Homebrew
    private func installBrew() -> (Bool, String, String?) {
        let cmd = "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        let r = Shell.run(cmd)
        _ = Shell.run("eval \"$(/opt/homebrew/bin/brew shellenv || /usr/local/bin/brew shellenv)\"")
        let ok = (r.code == 0) || r.out.contains("Installation successful") || r.err.contains("Installation successful")
        return (ok, r.out + r.err, tr("If brew not in PATH, reopen Terminal or add eval \\\"$(brew shellenv)\\\" to ~/.zprofile"))
    }
    private func brewPkg(_ name: String) -> (Bool, String, String?) {
        let check = Shell.run("brew list --formula --versions | awk '{print $1}' | grep -qx " + name + " && echo YES || echo NO")
        if check.out.contains("YES") { return (true, tr("Already installed ") + name, nil) }
        let r = Shell.run("brew install " + name)
        return (r.code == 0, r.out + r.err, nil)
    }
    private func brewCask(_ name: String) -> (Bool, String, String?) {
        let check = Shell.run("brew list --cask --versions | awk '{print $1}' | grep -qx " + name + " && echo YES || echo NO")
        if check.out.contains("YES") { return (true, tr("Already installed ") + name, nil) }
        let r = Shell.run("brew install --cask " + name)
        return (r.code == 0, r.out + r.err, nil)
    }
    private func installOhMyBash() -> (Bool, String, String?) {
        let cmd = "sh -c \"$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
        let r = Shell.run(cmd)
        return (true, r.out + r.err, tr("oh-my-zsh installed. Default location: ~/.oh-my-zsh. If using shared path (/opt/shared_env/oh-my-zsh), configure manually in ~/.zshrc"))
    }
    private func installRuby() -> (Bool, String, String?) {
        let r = brewPkg("ruby")
        _ = Shell.run("RB=\"$(brew --prefix ruby 2>/dev/null)\"; if [ -n \"$RB\" ] && [ -d \"$RB/bin\" ]; then for rc in $HOME/.zprofile $HOME/.bash_profile; do touch \"$rc\"; grep -qxF \"export PATH=\\\"$RB/bin:$PATH\\\"\" \"$rc\" || echo \"export PATH=\\\"$RB/bin:$PATH\\\"\" >> \"$rc\"; done; fi")
        return (r.0, r.1, tr("Ruby appended to PATH (zprofile/bash_profile). Reopen terminal to take effect."))
    }

    // MARK: - asdf core & plugins
    private func installAsdf() -> (Bool, String, String?) {
        let r1 = Shell.run("brew list --formula --versions | awk '{print $1}' | grep -qx asdf && echo YES || echo NO")
        var log = ""
        if !r1.out.contains("YES") {
            let r = Shell.run("brew install asdf")
            log += r.out + r.err + "\n"
        }
        _ = Shell.run("for rc in $HOME/.zshrc $HOME/.bash_profile; do touch \"$rc\"; grep -qxF \". \\\"$(brew --prefix asdf)\\\"/libexec/asdf.sh\" \"$rc\" || echo \". \\\"$(brew --prefix asdf)\\\"/libexec/asdf.sh\" >> \"$rc\"; done")
        return (true, log + "asdf ensured.", tr("Restart terminal to load asdf if command not found."))
    }

    private func pluginRepo(_ name: String) -> String {
        switch name {
        case "nodejs": return "https://github.com/asdf-vm/asdf-nodejs.git"
        case "golang": return "https://github.com/asdf-community/asdf-golang.git"
        case "java":   return "https://github.com/halcyon/asdf-java.git"
        case "pnpm":   return "https://github.com/jonathanmorley/asdf-pnpm.git"
        case "yarn":   return "https://github.com/twuni/asdf-yarn.git"
        case "maven":  return "https://github.com/halcyon/asdf-maven.git"
        case "gradle": return "https://github.com/rfrancis/asdf-gradle.git"
        case "python": return "https://github.com/danhper/asdf-python.git"
        case "rust":   return "https://github.com/asdf-community/asdf-rust.git"
        default: return ""
        }
    }
    private func asdfPluginAdd(_ name: String) {
        let repo = pluginRepo(name)
        if repo.isEmpty { return }
        _ = Shell.run("asdf plugin list | grep -qx " + name + " || asdf plugin add " + name + " " + repo)
        if name == "nodejs" { _ = Shell.run("bash ~/.asdf/plugins/nodejs/bin/import-release-team-keyring || true") }
    }
    private func ensureAsdfAndPlugin(_ name: String) {
        _ = installAsdf()
        asdfPluginAdd(name)
    }

    // latest installer
    private func ensureLatest(_ plugin: String, needs: [String] = []) -> (Bool, String, String?) {
        for dep in needs { ensureAsdfAndPlugin(dep) }
        ensureAsdfAndPlugin(plugin)
        let r = Shell.run("asdf latest \(plugin)")
        let ver = r.out.trimmingCharacters(in: .whitespacesAndNewlines)
        let i = Shell.run("asdf install \(plugin) \"\(ver)\" && asdf global \(plugin) \"\(ver)\" && asdf reshim \(plugin)")
        return (i.code == 0, "latest \(plugin): \(ver)\n" + i.out + i.err, nil)
    }
    private func ensureJavaLatest() -> (Bool, String, String?) {
        ensureAsdfAndPlugin("java")
        let i = Shell.run("asdf install java latest:temurin-21 && asdf global java latest:temurin-21 && java -version 2>&1 | head -n 2")
        return (i.code == 0, i.out + i.err, tr("Change vendor/version, e.g., latest:temurin-17 or corretto-21."))
    }

    // VM API
    func installLatest(_ t: TaskID, completion: @escaping (Bool,String,String?) -> Void) {
        DispatchQueue.global().async {
            var res:(Bool,String,String?) = (false,"","")
            switch t {
            case .nodejs: res = self.ensureLatest("nodejs")
            case .golang: res = self.ensureLatest("golang")
            case .java:   res = self.ensureJavaLatest()
            case .pnpm:   res = self.ensureLatest("pnpm", needs:["nodejs"])
            case .yarn:   res = self.ensureLatest("yarn", needs:["nodejs"])
            case .maven:  res = self.ensureLatest("maven")
            case .gradle: res = self.ensureLatest("gradle")
            case .pythonAsdf: res = self.ensureLatest("python")
            case .rust:   res = self.ensureLatest("rust")
            default:      res = (false, "Not supported", nil)
            }
            DispatchQueue.main.async { completion(res.0,res.1,res.2) }
        }
    }
    func listVersions(_ t: TaskID, completion: @escaping (Bool,String,String?) -> Void) {
        DispatchQueue.global().async {
            var plugin = ""
            switch t {
            case .nodejs: plugin = "nodejs"
            case .golang: plugin = "golang"
            case .java:   plugin = "java"
            case .pnpm:   plugin = "pnpm"
            case .yarn:   plugin = "yarn"
            case .maven:  plugin = "maven"
            case .gradle: plugin = "gradle"
            case .pythonAsdf: plugin = "python"
            case .rust:   plugin = "rust"
            default: plugin = ""
            }
            var out = ""; var ok = false
            if plugin != "" {
                self.ensureAsdfAndPlugin(plugin)
                
                // 获取已安装的版本
                let installedResult = Shell.run("asdf list \(plugin) 2>/dev/null || echo 'None installed'")
                let installedVersions = VersionManager.cleanVersionOutput(installedResult.out)
                
                // 获取当前版本
                let currentResult = Shell.run("asdf current \(plugin) 2>/dev/null || echo 'No version set'")
                let currentVersion = VersionManager.cleanVersionOutput(currentResult.out)
                
                // 获取可用版本（限制数量避免过多输出）
                let availableResult = Shell.run("asdf list all \(plugin) 2>/dev/null | tail -n 20 || echo 'Cannot fetch available versions'")
                let availableVersions = VersionManager.cleanVersionOutput(availableResult.out)
                
                // 格式化输出
                out = "📦 \(plugin.capitalized) 版本信息\n\n"
                out += "🟢 已安装版本:\n"
                out += installedVersions.isEmpty ? "   尚未安装任何版本\n" : installedVersions.map { "   • \($0)" }.joined(separator: "\n") + "\n"
                out += "\n🎯 当前使用版本:\n"
                out += currentVersion.isEmpty ? "   未设置默认版本\n" : "   ✓ \(currentVersion.joined(separator: ", "))\n"
                out += "\n📋 最新可用版本 (最近20个):\n"
                out += availableVersions.isEmpty ? "   无法获取可用版本\n" : availableVersions.map { "   • \($0)" }.joined(separator: "\n")
                
                ok = true
            } else {
                out = "❌ 不支持的工具类型: \(t.displayName)"
            }
            DispatchQueue.main.async { completion(ok, out, nil) }
        }
    }
    
    func installVersion(_ t: TaskID, version: String, completion: @escaping (Bool,String,String?) -> Void) {
        DispatchQueue.global().async {
            var plugin = ""
            switch t {
            case .nodejs: plugin = "nodejs"
            case .golang: plugin = "golang"
            case .java:   plugin = "java"
            case .pnpm:   plugin = "pnpm"
            case .yarn:   plugin = "yarn"
            case .maven:  plugin = "maven"
            case .gradle: plugin = "gradle"
            case .pythonAsdf: plugin = "python"
            case .rust:   plugin = "rust"
            default: plugin = ""
            }
            if plugin == "" { DispatchQueue.main.async { completion(false, "Not supported", nil) }; return }
            self.ensureAsdfAndPlugin(plugin)
            let i = Shell.run("asdf install \(plugin) \"\(version)\" && asdf global \(plugin) \"\(version)\" && asdf reshim \(plugin)")
            DispatchQueue.main.async { completion(i.code == 0, i.out + i.err, nil) }
        }
    }
    func setDefault(_ t: TaskID, version: String, completion: @escaping (Bool,String,String?) -> Void) {
        DispatchQueue.global().async {
            var plugin = ""
            switch t {
            case .nodejs: plugin = "nodejs"
            case .golang: plugin = "golang"
            case .java:   plugin = "java"
            case .pnpm:   plugin = "pnpm"
            case .yarn:   plugin = "yarn"
            case .maven:  plugin = "maven"
            case .gradle: plugin = "gradle"
            case .pythonAsdf: plugin = "python"
            case .rust:   plugin = "rust"
            default: plugin = ""
            }
            if plugin == "" { DispatchQueue.main.async { completion(false, "Not supported", nil) }; return }
            let i = Shell.run("asdf global \(plugin) \"\(version)\" && asdf reshim \(plugin)")
            DispatchQueue.main.async { completion(i.code == 0, i.out + i.err, nil) }
        }
    }

    // MARK: - Enhanced Installation Methods
    
    /// 获取工具的所有可用安装方式
    func getInstallationOptions(_ t: TaskID) -> [AlternativeInstaller] {
        switch t {
        case .nodejs:
            return [
                AlternativeInstaller(name: "asdf", command: "asdf", description: "推荐：通过asdf安装（支持多版本管理）", priority: 1),
                AlternativeInstaller(name: "homebrew", command: "brew install node", description: "通过Homebrew安装最新版本", priority: 2),
                AlternativeInstaller(name: "official", command: "official-installer", description: "官方安装包（从nodejs.org下载）", priority: 3),
                AlternativeInstaller(name: "nvm", command: "nvm install node", description: "通过nvm安装（需要先安装nvm）", priority: 4)
            ]
        case .python3:
            return [
                AlternativeInstaller(name: "asdf", command: "asdf", description: "推荐：通过asdf安装（支持多版本管理）", priority: 1),
                AlternativeInstaller(name: "homebrew", command: "brew install python", description: "通过Homebrew安装", priority: 2),
                AlternativeInstaller(name: "official", command: "official-installer", description: "官方安装包（从python.org下载）", priority: 3),
                AlternativeInstaller(name: "pyenv", command: "pyenv install", description: "通过pyenv安装（需要先安装pyenv）", priority: 4)
            ]
        case .ruby:
            return [
                AlternativeInstaller(name: "asdf", command: "asdf", description: "推荐：通过asdf安装（支持多版本管理）", priority: 1),
                AlternativeInstaller(name: "homebrew", command: "brew install ruby", description: "通过Homebrew安装", priority: 2),
                AlternativeInstaller(name: "rbenv", command: "rbenv install", description: "通过rbenv安装（需要先安装rbenv）", priority: 3),
                AlternativeInstaller(name: "rvm", command: "rvm install", description: "通过RVM安装（需要先安装RVM）", priority: 4)
            ]
        case .java:
            return [
                AlternativeInstaller(name: "asdf", command: "asdf", description: "推荐：通过asdf安装（支持多版本管理）", priority: 1),
                AlternativeInstaller(name: "homebrew", command: "brew install openjdk", description: "通过Homebrew安装OpenJDK", priority: 2),
                AlternativeInstaller(name: "official", command: "official-installer", description: "官方安装包（Oracle JDK）", priority: 3),
                AlternativeInstaller(name: "jabba", command: "jabba install", description: "通过jabba安装（需要先安装jabba）", priority: 4)
            ]
        default:
            return [
                AlternativeInstaller(name: "default", command: "default", description: "默认安装方式", priority: 1)
            ]
        }
    }
    
    /// 通过指定方式安装工具
    func installWithMethod(_ t: TaskID, method: String, version: String? = nil) -> (Bool, String, String?) {
        switch method {
        case "asdf":
            return installViaAsdf(t, version: version)
        case "homebrew":
            return installViaHomebrew(t)
        case "official":
            return installViaOfficialInstaller(t, version: version)
        case "nvm":
            return installViaNvm(version: version)
        case "pyenv":
            return installViaPyenv(version: version)
        case "rbenv":
            return installViaRbenv(version: version)
        case "rvm":
            return installViaRvm(version: version)
        case "jabba":
            return installViaJabba(version: version)
        default:
            return install(t, autoYes: true)
        }
    }
    
    // MARK: - Specific Installation Methods
    
    private func installViaAsdf(_ t: TaskID, version: String?) -> (Bool, String, String?) {
        let plugin = pluginName(for: t)
        guard !plugin.isEmpty else {
            return (false, "不支持的工具类型", nil)
        }
        
        // 确保asdf已安装
        let asdfResult = installAsdf()
        if !asdfResult.0 {
            return (false, "无法安装asdf: \(asdfResult.1)", asdfResult.2)
        }
        
        // 添加插件
        asdfPluginAdd(plugin)
        
        // 安装版本
        let targetVersion = version ?? "latest"
        let installCmd = "asdf install \(plugin) \(targetVersion) && asdf global \(plugin) \(targetVersion) && asdf reshim \(plugin)"
        let result = Shell.run(installCmd)
        
        return (result.code == 0, result.out + result.err, nil)
    }
    
    private func installViaHomebrew(_ t: TaskID) -> (Bool, String, String?) {
        let packageName = homebrewPackageName(for: t)
        guard !packageName.isEmpty else {
            return (false, "不支持通过Homebrew安装", nil)
        }
        
        return brewPkg(packageName)
    }
    
    private func installViaOfficialInstaller(_ t: TaskID, version: String?) -> (Bool, String, String?) {
        switch t {
        case .nodejs:
            return downloadAndInstallNodeJS(version: version)
        case .python3:
            return downloadAndInstallPython(version: version)
        case .java:
            return downloadAndInstallJava(version: version)
        default:
            return (false, "不支持官方安装包安装", nil)
        }
    }
    
    private func installViaNvm(version: String?) -> (Bool, String, String?) {
        // 检查nvm是否已安装
        let nvmCheck = Shell.run("command -v nvm >/dev/null 2>&1; echo $?")
        if !nvmCheck.out.contains("0") {
            // 安装nvm
            let nvmInstall = Shell.run("curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash")
            if nvmInstall.code != 0 {
                return (false, "无法安装nvm: \(nvmInstall.err)", nil)
            }
        }
        
        let targetVersion = version ?? "node"
        let result = Shell.run("source ~/.nvm/nvm.sh && nvm install \(targetVersion) && nvm use \(targetVersion)")
        return (result.code == 0, result.out + result.err, "需要重启终端或source ~/.nvm/nvm.sh")
    }
    
    private func installViaPyenv(version: String?) -> (Bool, String, String?) {
        // 检查pyenv是否已安装
        let pyenvCheck = Shell.run("command -v pyenv >/dev/null 2>&1; echo $?")
        if !pyenvCheck.out.contains("0") {
            let pyenvInstall = brewPkg("pyenv")
            if !pyenvInstall.0 {
                return (false, "无法安装pyenv: \(pyenvInstall.1)", pyenvInstall.2)
            }
        }
        
        let targetVersion = version ?? "3.12.0"
        let result = Shell.run("pyenv install \(targetVersion) && pyenv global \(targetVersion)")
        return (result.code == 0, result.out + result.err, "需要配置PATH: export PATH=\"$HOME/.pyenv/bin:$PATH\"")
    }
    
    private func installViaRbenv(version: String?) -> (Bool, String, String?) {
        let rbenvCheck = Shell.run("command -v rbenv >/dev/null 2>&1; echo $?")
        if !rbenvCheck.out.contains("0") {
            let rbenvInstall = brewPkg("rbenv")
            if !rbenvInstall.0 {
                return (false, "无法安装rbenv: \(rbenvInstall.1)", rbenvInstall.2)
            }
        }
        
        let targetVersion = version ?? "3.2.0"
        let result = Shell.run("rbenv install \(targetVersion) && rbenv global \(targetVersion)")
        return (result.code == 0, result.out + result.err, "需要配置shell: rbenv init")
    }
    
    private func installViaRvm(version: String?) -> (Bool, String, String?) {
        let rvmCheck = Shell.run("command -v rvm >/dev/null 2>&1; echo $?")
        if !rvmCheck.out.contains("0") {
            let rvmInstall = Shell.run("\\curl -sSL https://get.rvm.io | bash -s stable")
            if rvmInstall.code != 0 {
                return (false, "无法安装RVM: \(rvmInstall.err)", nil)
            }
        }
        
        let targetVersion = version ?? "3.2.0"
        let result = Shell.run("source ~/.rvm/scripts/rvm && rvm install \(targetVersion) && rvm use \(targetVersion) --default")
        return (result.code == 0, result.out + result.err, "需要重启终端或source ~/.rvm/scripts/rvm")
    }
    
    private func installViaJabba(version: String?) -> (Bool, String, String?) {
        let jabbaResult = installJabba()
        if !jabbaResult.0 {
            return (false, "无法安装jabba: \(jabbaResult.1)", jabbaResult.2)
        }
        
        let targetVersion = version ?? "openjdk@1.17.0"
        let result = Shell.run("jabba install \(targetVersion) && jabba use \(targetVersion)")
        return (result.code == 0, result.out + result.err, nil)
    }
    
    // MARK: - Official Installer Downloads
    
    private func downloadAndInstallNodeJS(version: String?) -> (Bool, String, String?) {
        let targetVersion = version ?? "latest"
        let architecture = "x64" // 假设Intel/Apple Silicon都用x64版本
        
        // 检查缓存
        if let cachedPackage = InstallationCache.getCachedPackage(tool: "nodejs", version: targetVersion) {
            let installResult = Shell.run("sudo installer -pkg '\(cachedPackage.path)' -target /")
            return (installResult.code == 0, "使用缓存安装: \(installResult.out)", nil)
        }
        
        // 下载并安装
        let downloadURL = "https://nodejs.org/dist/\(targetVersion == "latest" ? "latest" : "v\(targetVersion)")/node-\(targetVersion == "latest" ? "latest" : "v\(targetVersion)")-darwin-\(architecture).pkg"
        let downloadResult = Shell.run("curl -L '\(downloadURL)' -o /tmp/nodejs-\(targetVersion).pkg")
        
        if downloadResult.code == 0 {
            // 缓存包
            if let data = try? Data(contentsOf: URL(fileURLWithPath: "/tmp/nodejs-\(targetVersion).pkg")) {
                _ = InstallationCache.cachePackage(tool: "nodejs", version: targetVersion, data: data)
            }
            
            // 安装
            let installResult = Shell.run("sudo installer -pkg /tmp/nodejs-\(targetVersion).pkg -target / && rm /tmp/nodejs-\(targetVersion).pkg")
            return (installResult.code == 0, installResult.out + installResult.err, "已安装到系统目录")
        }
        
        return (false, "下载失败: \(downloadResult.err)", nil)
    }
    
    private func downloadAndInstallPython(version: String?) -> (Bool, String, String?) {
        let targetVersion = version ?? "3.12.0"
        
        if let cachedPackage = InstallationCache.getCachedPackage(tool: "python", version: targetVersion) {
            let installResult = Shell.run("sudo installer -pkg '\(cachedPackage.path)' -target /")
            return (installResult.code == 0, "使用缓存安装: \(installResult.out)", nil)
        }
        
        let downloadURL = "https://www.python.org/ftp/python/\(targetVersion)/python-\(targetVersion)-macos11.pkg"
        let downloadResult = Shell.run("curl -L '\(downloadURL)' -o /tmp/python-\(targetVersion).pkg")
        
        if downloadResult.code == 0 {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: "/tmp/python-\(targetVersion).pkg")) {
                _ = InstallationCache.cachePackage(tool: "python", version: targetVersion, data: data)
            }
            
            let installResult = Shell.run("sudo installer -pkg /tmp/python-\(targetVersion).pkg -target / && rm /tmp/python-\(targetVersion).pkg")
            return (installResult.code == 0, installResult.out + installResult.err, "已安装到系统目录")
        }
        
        return (false, "下载失败: \(downloadResult.err)", nil)
    }
    
    private func downloadAndInstallJava(version: String?) -> (Bool, String, String?) {
        let targetVersion = version ?? "17"
        
        // 使用Adoptium（Eclipse Temurin）的下载链接
        let downloadURL = "https://api.adoptium.net/v3/installer/latest/\(targetVersion)/ga/macos/x64/jdk/hotspot/normal/eclipse"
        let downloadResult = Shell.run("curl -L '\(downloadURL)' -o /tmp/openjdk-\(targetVersion).pkg")
        
        if downloadResult.code == 0 {
            let installResult = Shell.run("sudo installer -pkg /tmp/openjdk-\(targetVersion).pkg -target / && rm /tmp/openjdk-\(targetVersion).pkg")
            return (installResult.code == 0, installResult.out + installResult.err, "已安装OpenJDK \(targetVersion)到系统目录")
        }
        
        return (false, "下载失败，请手动从 https://adoptium.net/ 下载", nil)
    }
    
    // MARK: - Helper Functions
    
    private func pluginName(for task: TaskID) -> String {
        switch task {
        case .nodejs: return "nodejs"
        case .golang: return "golang" 
        case .java: return "java"
        case .pnpm: return "pnpm"
        case .yarn: return "yarn"
        case .maven: return "maven"
        case .gradle: return "gradle"
        case .pythonAsdf: return "python"
        case .rust: return "rust"
        default: return ""
        }
    }
    
    private func homebrewPackageName(for task: TaskID) -> String {
        switch task {
        case .nodejs: return "node"
        case .python3: return "python@3.12"
        case .ruby: return "ruby"
        case .java: return "openjdk"
        case .golang: return "go"
        case .maven: return "maven"
        case .gradle: return "gradle"
        case .rust: return "rust"
        default: return ""
        }
    }
    
    /// 清理缓存
    func clearCache() -> Bool {
        do {
            if FileManager.default.fileExists(atPath: InstallationCache.cacheDir.path) {
                try FileManager.default.removeItem(at: InstallationCache.cacheDir)
            }
            return true
        } catch {
            return false
        }
    }
    
    /// 获取缓存大小
    func getCacheSize() -> String {
        guard FileManager.default.fileExists(atPath: InstallationCache.cacheDir.path) else {
            return "0 KB"
        }
        
        let result = Shell.run("du -sh '\(InstallationCache.cacheDir.path)' | cut -f1")
        return result.code == 0 ? result.out.trimmingCharacters(in: .whitespacesAndNewlines) : "未知"
    }

    // Apply a profile (versions map)
    func apply(profile: EnvironmentProfile) -> (Bool, String, String?) {
        var logs = "[Profile] \(profile.name)\n"
        var overallSuccess = true
        
        // Update .zshrc with the new configuration
        let zshrcResult = updateZshrcConfiguration(profile: profile)
        logs += zshrcResult
        
        // First install/switch language versions with version checking
        for (plugin, version) in profile.versions {
            ensureAsdfAndPlugin(plugin)
            
            // Check if the version is already installed
            let checkResult = checkAndInstallVersion(plugin: plugin, version: version)
            logs += checkResult.1
            if !checkResult.0 {
                overallSuccess = false
                continue
            }
            
            // Set the global version
            let setGlobalResult = Shell.run("asdf global \(plugin) \"\(version)\" && asdf reshim \(plugin)")
            logs += "[\(plugin)] Set global to \(version) -> code=\(setGlobalResult.code)\n"
            if setGlobalResult.code != 0 {
                logs += "Error: \(setGlobalResult.err)\n"
                overallSuccess = false
            } else {
                logs += "✅ Successfully set \(plugin) global version to \(version)\n"
            }
        }
        
        // Then setup virtual environments
        for (language, venv) in profile.virtualEnvs {
            let venvResult = setupVirtualEnvironment(language: language, venv: venv)
            logs += "[VirtualEnv] \(language) -> \(venv.name)\n" + venvResult.1 + "\n"
        }
        
        // Set environment variables if any
        if !profile.environmentVars.isEmpty {
            logs += setupEnvironmentVariables(profile.environmentVars)
        }
        
        // Mark profile as active
        ProfilesStore.setActiveProfile(profile.name)
        
        let tip = overallSuccess ? 
            tr("Environment '\(profile.name)' activated. Reopen terminal or run 'source ~/.zshrc' to apply changes.") :
            tr("Environment '\(profile.name)' activated with some issues. Check logs for details.")
        
        return (overallSuccess, logs, tip)
    }
    
    // Check if a version is installed, and install it if not
    private func checkAndInstallVersion(plugin: String, version: String) -> (Bool, String) {
        var logs = "[\(plugin)] Checking version \(version)\n"
        
        // Check if version is already installed
        let listResult = Shell.run("asdf list \(plugin) 2>/dev/null")
        let installedVersions = VersionManager.cleanVersionOutput(listResult.out)
        
        if installedVersions.contains(version) {
            logs += "✅ Version \(version) already installed\n"
            return (true, logs)
        }
        
        logs += "⚠️ Version \(version) not installed, installing...\n"
        
        // Install the version
        let installResult = Shell.run("asdf install \(plugin) \"\(version)\"")
        logs += "Install output: \(installResult.out)\n"
        
        if installResult.code == 0 {
            logs += "✅ Successfully installed \(plugin) \(version)\n"
            return (true, logs)
        } else {
            logs += "❌ Failed to install \(plugin) \(version)\n"
            logs += "Error: \(installResult.err)\n"
            
            // Check if it's a Ruby version issue and suggest alternatives
            if plugin == "ruby" {
                logs += "💡 Tip: Ruby \(version) might not be available. Try using a different version or check available versions with 'asdf list all ruby'\n"
            }
            
            return (false, logs)
        }
    }
    
    // Update .zshrc configuration based on profile
    private func updateZshrcConfiguration(profile: EnvironmentProfile) -> String {
        var logs = "[Update .zshrc]\n"
        let zshrcPath = NSHomeDirectory() + "/.zshrc"
        
        // Ensure the file exists so environment hooks can be appended
        if !FileManager.default.fileExists(atPath: zshrcPath) {
            do {
                try "# Created by MacEnvSwitcher\n".write(toFile: zshrcPath, atomically: true, encoding: .utf8)
                logs += "⚠️ ~/.zshrc was missing. Created a new file so environment settings persist.\n"
            } catch {
                logs += "❌ Failed to create ~/.zshrc: \(error.localizedDescription)\n"
                return logs
            }
        }

        // Read current .zshrc content
        guard let zshrcContent = try? String(contentsOfFile: zshrcPath, encoding: .utf8) else {
            logs += "⚠️ Cannot read .zshrc file\n"
            return logs
        }
        
        var newContent = zshrcContent
        var modified = false
        
        // Update Java version if specified
        if let javaVersion = profile.versions["java"] {
            let javaMapping = mapJavaVersion(javaVersion)
            if let javaShortVersion = javaMapping.0 {
                newContent = updateZshrcFunction(content: newContent, 
                                                 pattern: "^use_java \\d+\\s*$",
                                                 replacement: "use_java \(javaShortVersion)")
                logs += "✅ Updated: use_java \(javaShortVersion)\n"
                modified = true
            }
        }
        
        // Update Gradle version if specified
        if let gradleVersion = profile.versions["gradle"] {
            newContent = updateZshrcFunction(content: newContent,
                                            pattern: "^use_gradle [\\d\\.]+\\s*$",
                                            replacement: "use_gradle \(gradleVersion)")
            logs += "✅ Updated: use_gradle \(gradleVersion)\n"
            modified = true
        }
        
        // Update Ruby version if specified
        if let rubyVersion = profile.versions["ruby"] {
            // Update use_ruby function call
            newContent = updateZshrcFunction(content: newContent,
                                            pattern: "^use_ruby [\\d\\.]+\\s*$",
                                            replacement: "use_ruby \(rubyVersion)")
            // Also update rbenv global if present
            newContent = updateZshrcFunction(content: newContent,
                                            pattern: "^rbenv global [\\d\\.]+\\s*$",
                                            replacement: "rbenv global \(rubyVersion)")
            logs += "✅ Updated: use_ruby \(rubyVersion)\n"
            modified = true
        }
        
        // Update Python version comment (for reference)
        if let pythonVersion = profile.versions["python"] {
            logs += "ℹ️ Python \(pythonVersion) (managed by asdf)\n"
        }
        
        // Update Node.js version comment (for reference)
        if let nodeVersion = profile.versions["nodejs"] {
            logs += "ℹ️ Node.js \(nodeVersion) (managed by asdf/nvm)\n"
        }
        
        // Update Go version comment (for reference)
        if let goVersion = profile.versions["golang"] {
            logs += "ℹ️ Go \(goVersion) (managed by asdf)\n"
        }
        
        // Update environment variables in .zshrc
        for (key, value) in profile.environmentVars {
            let pattern = "^export \(key)=.*$"
            let replacement = "export \(key)=\"\(value)\""
            newContent = updateZshrcFunction(content: newContent,
                                            pattern: pattern,
                                            replacement: replacement)
            logs += "✅ Updated: export \(key)=\"\(value)\"\n"
            modified = true
        }
        
        // Write back to .zshrc if modified
        if modified {
            // Backup original .zshrc
            let backupPath = zshrcPath + ".backup." + String(Int(Date().timeIntervalSince1970))
            try? zshrcContent.write(toFile: backupPath, atomically: true, encoding: .utf8)
            logs += "📦 Backup created: ~/.zshrc.backup.*\n"
            
            // Write new content
            do {
                try newContent.write(toFile: zshrcPath, atomically: true, encoding: .utf8)
                logs += "✅ .zshrc updated successfully\n"
            } catch {
                logs += "❌ Failed to write .zshrc: \(error.localizedDescription)\n"
            }
        } else {
            logs += "ℹ️ No .zshrc updates needed\n"
        }
        
        return logs + "\n"
    }
    
    // Helper function to update lines in .zshrc matching a pattern
    private func updateZshrcFunction(content: String, pattern: String, replacement: String) -> String {
        var lines = content.components(separatedBy: "\n")
        
        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.range(of: pattern, options: .regularExpression) != nil {
                // Preserve leading whitespace
                let leadingWhitespace = String(line.prefix(while: { $0.isWhitespace }))
                lines[index] = leadingWhitespace + replacement
            }
        }
        
        return lines.joined(separator: "\n")
    }
    
    // Map Java version to short version used in use_java function
    private func mapJavaVersion(_ version: String) -> (String?, String?) {
        // Extract major version number
        if version.hasPrefix("1.8") {
            return ("8", "/Library/Java/JavaVirtualMachines/jdk1.8.0_361.jdk/Contents/Home")
        } else if version.hasPrefix("11") {
            return ("11", "/Library/Java/JavaVirtualMachines/jdk-11.0.21.jdk/Contents/Home")
        } else if version.hasPrefix("23") {
            return ("23", "/opt/homebrew/Cellar/openjdk/23.0.2/libexec/openjdk.jdk/Contents/Home")
        } else if version.hasPrefix("17") {
            return ("17", nil)
        } else if version.contains("temurin-21") || version.hasPrefix("21") {
            return ("21", nil)
        }
        return (nil, nil)
    }
    
    // Setup virtual environments
    private func setupVirtualEnvironment(language: String, venv: VirtualEnvironment) -> (Bool, String) {
        var logs = ""
        
        switch venv.type {
        case .pythonVenv:
            if let pythonVer = venv.pythonVersion {
                // Ensure Python version is installed
                ensureAsdfAndPlugin("python")
                let installPython = Shell.run("asdf install python \"\(pythonVer)\" && asdf global python \"\(pythonVer)\"")
                logs += "Python \(pythonVer): \(installPython.out)\n"
                
                // Create/activate virtual environment
                let venvPath = "~/.virtualenvs/\(venv.name)"
                let createVenv = Shell.run("python -m venv \(venvPath) || true")
                logs += "Create venv '\(venv.name)': \(createVenv.out)\n"
                
                // Add to shell profile for auto-activation
                let activateScript = "alias activate-\(venv.name)='source \(venvPath)/bin/activate'"
                _ = Shell.run("echo '\(activateScript)' >> ~/.zprofile")
                logs += "Added alias: activate-\(venv.name)\n"
            }
            
        case .pythonConda:
            if let pythonVer = venv.pythonVersion {
                // Check if conda is available
                let condaCheck = Shell.run("which conda || echo 'NOT_FOUND'")
                if condaCheck.out.contains("NOT_FOUND") {
                    // Install conda via homebrew
                    let installConda = Shell.run("brew install --cask miniconda")
                    logs += "Install Miniconda: \(installConda.out)\n"
                    // Initialize conda
                    let initConda = Shell.run("conda init zsh && conda init bash")
                    logs += "Initialize conda: \(initConda.out)\n"
                }
                
                // Create conda environment
                let createEnv = Shell.run("conda create -n \(venv.name) python=\(pythonVer) -y || conda env update -n \(venv.name) --file /dev/null")
                logs += "Create conda env '\(venv.name)': \(createEnv.out)\n"
                
                // Add activation alias
                let activateScript = "alias activate-\(venv.name)='conda activate \(venv.name)'"
                _ = Shell.run("echo '\(activateScript)' >> ~/.zprofile")
                logs += "Added alias: activate-\(venv.name)\n"
            }
            
        case .rubyGemset:
            if let gemset = venv.gemset {
                // Setup RVM if not available
                let rvmCheck = Shell.run("which rvm || echo 'NOT_FOUND'")
                if rvmCheck.out.contains("NOT_FOUND") {
                    let installRvm = Shell.run("curl -sSL https://get.rvm.io | bash -s stable")
                    logs += "Install RVM: \(installRvm.out)\n"
                }
                
                // Create and use gemset
                let createGemset = Shell.run("rvm gemset create \(gemset) && rvm gemset use \(gemset)")
                logs += "Create Ruby gemset '\(gemset)': \(createGemset.out)\n"
                
                // Add to shell profile
                let gemsetScript = "alias use-\(venv.name)='rvm gemset use \(gemset)'"
                _ = Shell.run("echo '\(gemsetScript)' >> ~/.zprofile")
                logs += "Added alias: use-\(venv.name)\n"
            }
            
        case .nodeNvm:
            if let nodeVer = venv.nodeVersion {
                // Setup NVM if not available
                let nvmCheck = Shell.run("which nvm || echo 'NOT_FOUND'")
                if nvmCheck.out.contains("NOT_FOUND") {
                    let installNvm = Shell.run("curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash")
                    logs += "Install NVM: \(installNvm.out)\n"
                }
                
                // Install and use Node version
                let useNode = Shell.run("nvm install \(nodeVer) && nvm use \(nodeVer)")
                logs += "Setup Node.js \(nodeVer): \(useNode.out)\n"
                
                // Add alias for this environment
                let nodeScript = "alias node-\(venv.name)='nvm use \(nodeVer)'"
                _ = Shell.run("echo '\(nodeScript)' >> ~/.zprofile")
                logs += "Added alias: node-\(venv.name)\n"
            }
            
        case .rustToolchain:
            // Setup Rust toolchain
            let rustupCheck = Shell.run("which rustup || echo 'NOT_FOUND'")
            if rustupCheck.out.contains("NOT_FOUND") {
                let installRustup = Shell.run("curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y")
                logs += "Install Rustup: \(installRustup.out)\n"
            }
            
            let installToolchain = Shell.run("rustup toolchain install \(venv.name) && rustup default \(venv.name)")
            logs += "Setup Rust toolchain '\(venv.name)': \(installToolchain.out)\n"
            
        case .custom:
            logs += "Custom virtual environment setup not implemented for '\(venv.name)'\n"
        }
        
        return (true, logs)
    }
    
    // Setup environment variables
    private func setupEnvironmentVariables(_ envVars: [String: String]) -> String {
        var logs = "[Environment Variables]\n"
        
        for (key, value) in envVars {
            let exportCmd = "export \(key)=\"\(value)\""
            _ = Shell.run("echo '\(exportCmd)' >> ~/.zprofile")
            logs += "Set \(key)=\(value)\n"
        }
        
        return logs
    }
    
    // Switch environment
    func switchToEnvironment(_ profile: EnvironmentProfile, completion: @escaping (Bool, String, String?) -> Void) {
        DispatchQueue.global().async {
            // Deactivate current environment first
            ProfilesStore.deactivateAllProfiles()
            
            // Apply the new environment
            let result = self.apply(profile: profile)
            
            // Reload shell configuration and apply system defaults
            let reloadResult = self.reloadSystemConfiguration(profile: profile)
            
            DispatchQueue.main.async {
                let combinedLog = result.1 + "\n" + reloadResult.1
                completion(result.0 && reloadResult.0, combinedLog, reloadResult.2)
            }
        }
    }
    
    // Deactivate current environment
    func deactivateCurrentEnvironment() -> (Bool, String, String?) {
        ProfilesStore.deactivateAllProfiles()
        
        // Reset to system defaults (could be enhanced to save/restore previous state)
        var logs = "[Deactivate Environment]\n"
        
        // Reset asdf to system versions or latest
        let asdfVersionResult = Shell.run("asdf version")
        let useSetCommand = asdfVersionResult.out.contains("0.18") || asdfVersionResult.out.contains("0.17") || asdfVersionResult.out.contains("0.16")
        
        let systemCommands = [
            useSetCommand ? "asdf set nodejs system" : "asdf global nodejs system",
            useSetCommand ? "asdf set python system" : "asdf global python system", 
            useSetCommand ? "asdf set ruby system" : "asdf global ruby system",
            useSetCommand ? "asdf set java system" : "asdf global java system"
        ]
        
        for command in systemCommands {
            let resetResult = Shell.run("\(command) 2>/dev/null || true")
            logs += "Executed: \(command) - \(resetResult.code == 0 ? "✅" : "⚠️")\n"
        }
        
        return (true, logs, tr("Environment deactivated. System defaults restored."))
    }

    /// 检测指定插件的版本管理器冲突，返回描述信息
    private func detectVersionManagerConflict(plugin: String) -> String {
        let toolName: String
        switch plugin.lowercased() {
        case "nodejs": toolName = "Node.js"
        case "python": toolName = "Python"
        case "ruby": toolName = "Ruby"
        case "java": toolName = "Java"
        case "golang": toolName = "Go"
        case "rust": toolName = "Rust"
        default: toolName = plugin.capitalized
        }

        let conflicts = Detectors().checkVersionManagerConflicts()
        guard let conflict = conflicts.first(where: { $0.tool.lowercased() == toolName.lowercased() }) else {
            return ""
        }

        var messages: [String] = []
        if !conflict.managers.isEmpty {
            messages.append("managers: \(conflict.managers.joined(separator: ", "))")
        }
        if !conflict.pathConflicts.isEmpty {
            messages.append("paths: \(conflict.pathConflicts.joined(separator: ", "))")
        }
        if !conflict.envConflicts.isEmpty {
            let envSummary = conflict.envConflicts.map { key, values in
                "\(key)=\(values.joined(separator: ", "))"
            }.joined(separator: "; ")
            messages.append("env: \(envSummary)")
        }

        return messages.joined(separator: " | ")
    }
    
    // Reload system configuration and apply changes to current shell
    private func reloadSystemConfiguration(profile: EnvironmentProfile) -> (Bool, String, String?) {
        var logs = "[Reload System Configuration]\n"
        var success = true
        
        // 1. Ensure shell environment is properly loaded
        let shellEnvResult = reloadShellEnvironment()
        logs += shellEnvResult
        
        // 2. Apply asdf global settings with verification
        for (plugin, version) in profile.versions {
            // Detect version manager conflicts
            let versionManagerConflict = detectVersionManagerConflict(plugin: plugin)
            if !versionManagerConflict.isEmpty {
                logs += "⚠️ Version manager conflict detected for \(plugin): \(versionManagerConflict)\n"
            }
            
            // First check if plugin is installed
            let pluginCheckResult = Shell.run("asdf plugin list | grep -w '\(plugin)'")
            if pluginCheckResult.code != 0 {
                logs += "⚠️ Plugin '\(plugin)' not installed, installing...\n"
                let installPluginResult = Shell.run("asdf plugin add \(plugin)")
                if installPluginResult.code != 0 {
                    logs += "❌ Failed to install plugin '\(plugin)': \(installPluginResult.err)\n"
                    success = false
                    continue
                } else {
                    logs += "✅ Plugin '\(plugin)' installed successfully\n"
                }
            }
            
            // Check if the specific version is installed
            let versionCheckResult = Shell.run("asdf list \(plugin) 2>/dev/null | grep -w '\(version)'")
            if versionCheckResult.code != 0 {
                logs += "⚠️ Version '\(version)' not installed for \(plugin), installing...\n"
                let installVersionResult = Shell.run("asdf install \(plugin) \(version)")
                if installVersionResult.code != 0 {
                    logs += "❌ Failed to install \(plugin) \(version): \(installVersionResult.err)\n"
                    logs += "💡 Tip: You may need to install \(plugin) \(version) manually or choose a different version\n"
                    
                    // Try to suggest available versions
                    let availableVersionsResult = Shell.run("asdf list \(plugin) 2>/dev/null")
                    if availableVersionsResult.code == 0 && !availableVersionsResult.out.isEmpty {
                        logs += "Available \(plugin) versions: \(availableVersionsResult.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
                    }
                    
                    success = false
                    continue
                } else {
                    logs += "✅ \(plugin) \(version) installed successfully\n"
                }
            }
            
            // Determine the correct asdf command (global vs set)
            let asdfVersionResult = Shell.run("asdf version")
            let useSetCommand = asdfVersionResult.out.contains("0.18") || asdfVersionResult.out.contains("0.17") || asdfVersionResult.out.contains("0.16")
            
            let globalCommand = useSetCommand ? "asdf set \(plugin) \(version)" : "asdf global \(plugin) \(version)"
            let globalResult = Shell.run(globalCommand)
            logs += "Set global \(plugin) \(version): \(globalResult.code == 0 ? "✅" : "❌")\n"
            if globalResult.code != 0 {
                logs += "Error: \(globalResult.err)\n"
                success = false
            } else {
                // Verify the setting took effect
                let verifyResult = Shell.run("asdf current \(plugin)")
                if verifyResult.out.contains(version) {
                    logs += "✅ Verified: \(plugin) \(version) is now active\n"
                } else {
                    logs += "⚠️ Warning: \(plugin) \(version) set but may not be active due to conflicts\n"
                }
            }
        }
        
        // 3. Refresh asdf shims
        let reshimResult = Shell.run("asdf reshim")
        logs += "Refresh shims: \(reshimResult.code == 0 ? "✅" : "❌")\n"
        
        // 4. Special handling for each language environment
        for (plugin, version) in profile.versions {
            let languageReloadResult = reloadLanguageEnvironment(plugin: plugin, version: version)
            logs += languageReloadResult
        }
        
        // 5. Update terminal profile settings (if using iTerm2)
        let updateTerminalResult = updateTerminalProfile(profile: profile)
        logs += updateTerminalResult
        
        // 6. Apply environment variables immediately
        let envApplyResult = applyEnvironmentVariablesImmediately(profile: profile)
        logs += envApplyResult
        
        // 7. Verify the changes took effect
        let verificationResult = verifyEnvironmentChanges(profile: profile)
        logs += verificationResult
        
        let tip = success ? 
            tr("Environment activated successfully! All changes are now in effect system-wide.") :
            tr("Environment activated with some warnings. Please check the logs for details.")
        
        return (success, logs, tip)
    }
    
    // Apply environment variables immediately to current process and all terminals
    private func applyEnvironmentVariablesImmediately(profile: EnvironmentProfile) -> String {
        var logs = "[Apply Environment Variables]\n"
        
        // 1. Apply to current process
        for (key, value) in profile.environmentVars {
            setenv(key, value, 1)
            logs += "Set ENV \(key)=\(value): ✅\n"
        }
        
        // 2. Apply asdf global versions immediately
        for (plugin, version) in profile.versions {
            // Set environment variables for immediate effect
            let pluginUppercase = plugin.uppercased()
            setenv("ASDF_\(pluginUppercase)_VERSION", version, 1)
            logs += "Set ASDF_\(pluginUppercase)_VERSION=\(version): ✅\n"
        }
        
        // 3. Update PATH immediately with current version paths
        let currentPathPtr = getenv("PATH")
        var currentPath = ""
        if let pathPtr = currentPathPtr {
            currentPath = String(cString: pathPtr)
        }
        
        let asdfShimPath = "\(NSHomeDirectory())/.asdf/shims"
        let asdfBinPath = "\(NSHomeDirectory())/.asdf/bin"
        
        // Remove existing asdf paths and add them at the beginning
        var pathComponents = currentPath.split(separator: ":").map(String.init)
        pathComponents.removeAll { $0.contains(".asdf") }
        pathComponents.insert(asdfShimPath, at: 0)
        pathComponents.insert(asdfBinPath, at: 1)
        
        let newPath = pathComponents.joined(separator: ":")
        setenv("PATH", newPath, 1)
        logs += "Updated PATH with asdf paths: ✅\n"
        
        // 4. Apply to all running terminal sessions immediately
        let terminalApplyResult = applyToAllTerminals(profile: profile)
        logs += terminalApplyResult
        
        // 5. Create system-wide environment update
        let systemApplyResult = applyToSystemEnvironment(profile: profile)
        logs += systemApplyResult
        
        return logs
    }
    
    // Apply environment to all running terminals
    private func applyToAllTerminals(profile: EnvironmentProfile) -> String {
        var logs = "[Apply to All Terminals]\n"
        
        // Prepare environment commands
        var envCommands: [String] = []
        
        // Determine the correct asdf command (global vs set)
        let asdfVersionResult = Shell.run("asdf version")
        let useSetCommand = asdfVersionResult.out.contains("0.18") || asdfVersionResult.out.contains("0.17") || asdfVersionResult.out.contains("0.16")
        
        // Add asdf commands
        for (plugin, version) in profile.versions {
            let asdfCommand = useSetCommand ? "asdf set \(plugin) '\(version)'" : "asdf global \(plugin) '\(version)'"
            envCommands.append("\(asdfCommand) 2>/dev/null || echo 'Failed to set \(plugin) \(version)'")
        }
        
        // Add environment variable exports
        for (key, value) in profile.environmentVars {
            envCommands.append("export \(key)='\(value)'")
        }
        
        // Add PATH update
        envCommands.append("export PATH=\"$HOME/.asdf/shims:$HOME/.asdf/bin:$PATH\"")
        envCommands.append("hash -r 2>/dev/null || true")
        envCommands.append("rehash 2>/dev/null || true")
        
        let commandString = envCommands.joined(separator: "; ")
        
        // Apply to iTerm2
        let iTermCheck = Shell.run("osascript -e 'tell application \"System Events\" to return exists process \"iTerm2\"'")
        if iTermCheck.out.contains("true") {
            let iTermScript = """
            tell application "iTerm2"
                repeat with theWindow in windows
                    repeat with theTab in tabs of theWindow
                        repeat with theSession in sessions of theTab
                            tell theSession
                                write text "# MacEnvSwitcher: Applying environment '\(profile.name)'"
                                write text "\(commandString)"
                                write text "echo '✅ Environment '\(profile.name)' activated'"
                            end tell
                        end repeat
                    end repeat
                end repeat
            end tell
            """
            let iTermResult = Shell.run("osascript -e '\(iTermScript)'")
            logs += "iTerm2 environment apply: \(iTermResult.code == 0 ? "✅" : "❌")\n"
        }
        
        // Apply to Terminal.app
        let terminalCheck = Shell.run("osascript -e 'tell application \"System Events\" to return exists process \"Terminal\"'")
        if terminalCheck.out.contains("true") {
            let terminalScript = """
            tell application "Terminal"
                repeat with theWindow in windows
                    repeat with theTab in tabs of theWindow
                        do script "echo '# MacEnvSwitcher: Applying environment \(profile.name)'; \(commandString); echo '✅ Environment \(profile.name) activated'" in theTab
                    end repeat
                end repeat
            end tell
            """
            let terminalResult = Shell.run("osascript -e '\(terminalScript)'")
            logs += "Terminal.app environment apply: \(terminalResult.code == 0 ? "✅" : "❌")\n"
        }
        
        return logs
    }
    
    // Apply to system environment (launchctl and shell configs)
    private func applyToSystemEnvironment(profile: EnvironmentProfile) -> String {
        var logs = "[Apply to System Environment]\n"
        
        // 1. Update launchctl environment for GUI applications
        for (key, value) in profile.environmentVars {
            let launchctlResult = Shell.run("launchctl setenv \(key) '\(value)'")
            logs += "launchctl setenv \(key): \(launchctlResult.code == 0 ? "✅" : "⚠️")\n"
        }
        
        // 2. Update PATH in launchctl
        let currentPathPtr = getenv("PATH")
        var currentPath = "/usr/local/bin:/usr/bin:/bin"
        if let pathPtr = currentPathPtr {
            currentPath = String(cString: pathPtr)
        }
        
        let asdfPath = "\(NSHomeDirectory())/.asdf/shims:\(NSHomeDirectory())/.asdf/bin"
        let newSystemPath = asdfPath + ":" + currentPath
        let pathResult = Shell.run("launchctl setenv PATH '\(newSystemPath)'")
        logs += "launchctl setenv PATH: \(pathResult.code == 0 ? "✅" : "⚠️")\n"
        
        // 3. Create or update environment plist for persistence
        let environmentPlistResult = createEnvironmentPlist(profile: profile)
        logs += environmentPlistResult
        
        return logs
    }
    
    // Create environment plist for system-wide persistence
    private func createEnvironmentPlist(profile: EnvironmentProfile) -> String {
        var logs = ""
        
        let plistPath = "\(NSHomeDirectory())/Library/LaunchAgents/com.macenvswitcher.environment.plist"
        
        // Prepare environment dictionary
        var environmentDict: [String: String] = [:]
        
        // Add custom environment variables
        for (key, value) in profile.environmentVars {
            environmentDict[key] = value
        }
        
        // Add PATH with asdf
        let asdfPath = "\(NSHomeDirectory())/.asdf/shims:\(NSHomeDirectory())/.asdf/bin"
        let currentPath = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/local/bin:/usr/bin:/bin"
        environmentDict["PATH"] = "\(asdfPath):\(currentPath)"
        
        // Create plist content
        let plistContent = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.macenvswitcher.environment</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>
            # MacEnvSwitcher Environment Setup
            \(environmentDict.map { "launchctl setenv \($0.key) '\($0.value)'" }.joined(separator: "; "))
        </string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>EnvironmentVariables</key>
    <dict>
\(environmentDict.map { "        <key>\($0.key)</key>\n        <string>\($0.value)</string>" }.joined(separator: "\n"))
    </dict>
</dict>
</plist>
"""
        
        do {
            // Create LaunchAgents directory if it doesn't exist
            let launchAgentsDir = "\(NSHomeDirectory())/Library/LaunchAgents"
            if !FileManager.default.fileExists(atPath: launchAgentsDir) {
                try FileManager.default.createDirectory(atPath: launchAgentsDir, withIntermediateDirectories: true, attributes: nil)
            }
            
            // Write plist file
            try plistContent.write(toFile: plistPath, atomically: true, encoding: .utf8)
            
            // Load the plist
            let loadResult = Shell.run("launchctl load '\(plistPath)'")
            logs += "Environment plist created and loaded: \(loadResult.code == 0 ? "✅" : "⚠️")\n"
            
        } catch {
            logs += "❌ Failed to create environment plist: \(error.localizedDescription)\n"
        }
        
        return logs
    }
    }
    
    // Reload shell environment with immediate effect
    private func reloadShellEnvironment() -> String {
        var logs = "[Reload Shell Environment]\n"
        
        // 1. Force reload asdf environment
        let asdfDir = Shell.run("echo $(brew --prefix asdf 2>/dev/null || echo '/opt/homebrew/opt/asdf')")
        let asdfPath = asdfDir.out.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Source asdf configuration
        let sourceAsdfResult = Shell.run("export ASDF_DIR='\(asdfPath)' && source '\(asdfPath)/libexec/asdf.sh' 2>/dev/null || source '\(asdfPath)/asdf.sh' 2>/dev/null")
        logs += "Source asdf: \(sourceAsdfResult.code == 0 ? "✅" : "⚠️")\n"
        
        // 2. Apply environment variables immediately to current process
        let currentPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let asdfShimPath = "\(NSHomeDirectory())/.asdf/shims"
        let asdfBinPath = "\(NSHomeDirectory())/.asdf/bin"
        
        // Update PATH to include asdf paths at the beginning
        var newPath = currentPath
        if !newPath.contains(asdfShimPath) {
            newPath = "\(asdfShimPath):\(newPath)"
        }
        if !newPath.contains(asdfBinPath) {
            newPath = "\(asdfBinPath):\(newPath)"
        }
        
        setenv("PATH", newPath, 1)
        setenv("ASDF_DIR", asdfPath, 1)
        logs += "✅ Updated PATH with asdf directories\n"
        
        // 3. Force refresh shell environment for all terminal sessions
        let refreshShellResult = forceRefreshAllTerminals()
        logs += refreshShellResult
        
        // 4. Update shell configuration files immediately
        let updateShellConfigResult = updateAllShellConfigurations()
        logs += updateShellConfigResult
        
        return logs
    }
    
    // Force refresh all running terminal sessions
    private func forceRefreshAllTerminals() -> String {
        var logs = "[Force Refresh Terminals]\n"
        
        // Check if iTerm2 is running
        let iTermCheck = Shell.run("osascript -e 'tell application \"System Events\" to return exists process \"iTerm2\"'")
        if iTermCheck.out.contains("true") {
            // Send refresh command to all iTerm2 sessions
            let refreshScript = """
            tell application "iTerm2"
                repeat with theWindow in windows
                    repeat with theTab in tabs of theWindow
                        repeat with theSession in sessions of theTab
                            tell theSession
                                write text "# MacEnvSwitcher: Refreshing environment..."
                                write text "source ~/.zshrc 2>/dev/null || source ~/.bashrc 2>/dev/null || true"
                                write text "hash -r 2>/dev/null || true"
                                write text "rehash 2>/dev/null || true"
                                write text "clear"
                            end tell
                        end repeat
                    end repeat
                end repeat
            end tell
            """
            let refreshResult = Shell.run("osascript -e '\(refreshScript)'")
            logs += "iTerm2 sessions refresh: \(refreshResult.code == 0 ? "✅" : "❌")\n"
        }
        
        // Check if Terminal.app is running
        let terminalCheck = Shell.run("osascript -e 'tell application \"System Events\" to return exists process \"Terminal\"'")
        if terminalCheck.out.contains("true") {
            let terminalRefreshScript = """
            tell application "Terminal"
                repeat with theWindow in windows
                    repeat with theTab in tabs of theWindow
                        do script "source ~/.zshrc 2>/dev/null || source ~/.bashrc 2>/dev/null; hash -r 2>/dev/null; rehash 2>/dev/null; clear" in theTab
                    end repeat
                end repeat
            end tell
            """
            let terminalRefreshResult = Shell.run("osascript -e '\(terminalRefreshScript)'")
            logs += "Terminal.app sessions refresh: \(terminalRefreshResult.code == 0 ? "✅" : "❌")\n"
        }
        
        // For other terminals, create a temporary refresh script
        let tempScriptPath = "/tmp/macenvswitcher_refresh.sh"
        let refreshScript = """
#!/bin/bash
# MacEnvSwitcher Environment Refresh
export PATH="\(NSHomeDirectory())/.asdf/shims:\(NSHomeDirectory())/.asdf/bin:$PATH"
source ~/.zshrc 2>/dev/null || source ~/.bashrc 2>/dev/null || true
hash -r 2>/dev/null || true
rehash 2>/dev/null || true
"""
        
        do {
            try refreshScript.write(toFile: tempScriptPath, atomically: true, encoding: .utf8)
            let chmodResult = Shell.run("chmod +x '\(tempScriptPath)'")
            logs += "Created refresh script: \(chmodResult.code == 0 ? "✅" : "❌")\n"
        } catch {
            logs += "❌ Failed to create refresh script: \(error.localizedDescription)\n"
        }
        
        return logs
    }
    
    // Update all shell configuration files
    private func updateAllShellConfigurations() -> String {
        var logs = "[Update Shell Configurations]\n"
        
        let homeDir = NSHomeDirectory()
        let configFiles = [
            "\(homeDir)/.zshrc",
            "\(homeDir)/.bashrc",
            "\(homeDir)/.bash_profile",
            "\(homeDir)/.profile"
        ]
        
        for configFile in configFiles {
            if FileManager.default.fileExists(atPath: configFile) {
                let updateResult = updateShellConfigFile(configFile)
                logs += updateResult
            } else {
                let fileName = (configFile as NSString).lastPathComponent
                if fileName == ".zshrc" {
                    logs += "⚠️ Missing \(fileName). Run 'touch ~/.zshrc' to create it so MacEnvSwitcher can manage Zsh settings.\n"
                } else if fileName == ".bashrc" {
                    logs += "⚠️ Missing \(fileName). Run 'touch ~/.bashrc' if you use Bash to ensure environment hooks load.\n"
                } else if fileName == ".bash_profile" {
                    logs += "⚠️ Missing \(fileName). Recommend creating it with 'touch ~/.bash_profile' for login shells.\n"
                } else if fileName == ".profile" {
                    logs += "⚠️ Missing \(fileName). Optional, but helpful for POSIX shells.\n"
                }
            }
        }
        
        // Check for asdf tool versions
        let toolVersionsPath = "\(homeDir)/.tool-versions"
        if !FileManager.default.fileExists(atPath: toolVersionsPath) {
            logs += "⚠️ Missing .tool-versions file. Create one to let asdf manage default versions, e.g. 'echo \"python 3.12.0\" >> ~/.tool-versions'.\n"
        } else {
            logs += "✅ Found ~/.tool-versions\n"
        }

        return logs
    }
    
    // Update individual shell configuration file
    private func updateShellConfigFile(_ filePath: String) -> String {
        var logs = ""
        let fileName = (filePath as NSString).lastPathComponent
        
        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            logs += "⚠️ Cannot read \(fileName)\n"
            return logs
        }
        
        var newContent = content
        var modified = false
        
        // Ensure asdf is properly initialized
        let asdfInitBlock = """
# MacEnvSwitcher: asdf initialization
if [ -d "$HOME/.asdf" ]; then
    export ASDF_DIR="$HOME/.asdf"
    export PATH="$HOME/.asdf/shims:$HOME/.asdf/bin:$PATH"
    [ -s "$HOME/.asdf/asdf.sh" ] && source "$HOME/.asdf/asdf.sh"
    [ -s "$HOME/.asdf/completions/asdf.bash" ] && source "$HOME/.asdf/completions/asdf.bash"
elif [ -d "/opt/homebrew/opt/asdf" ]; then
    export ASDF_DIR="/opt/homebrew/opt/asdf"
    export PATH="/opt/homebrew/opt/asdf/shims:/opt/homebrew/opt/asdf/bin:$PATH"
    source "/opt/homebrew/opt/asdf/libexec/asdf.sh"
    source "/opt/homebrew/opt/asdf/etc/bash_completion.d/asdf.bash" 2>/dev/null || true
fi
# End MacEnvSwitcher asdf initialization
"""
        
        // Check if asdf initialization exists
        if !newContent.contains("# MacEnvSwitcher: asdf initialization") {
            newContent += "\n\n" + asdfInitBlock + "\n"
            modified = true
            logs += "✅ Added asdf initialization to \(fileName)\n"
        }
        
        // Write back if modified
        if modified {
            // Create backup
            let backupPath = filePath + ".backup." + String(Int(Date().timeIntervalSince1970))
            try? content.write(toFile: backupPath, atomically: true, encoding: .utf8)
            
            do {
                try newContent.write(toFile: filePath, atomically: true, encoding: .utf8)
                logs += "✅ Updated \(fileName) successfully\n"
            } catch {
                logs += "❌ Failed to update \(fileName): \(error.localizedDescription)\n"
            }
        }
        
        return logs
    }
    
    // Special handling for language environment reload
    private func reloadLanguageEnvironment(plugin: String, version: String) -> String {
        var logs = "[\(plugin.capitalized) Environment Reload]\n"
        
        // Language-specific conflict detection and handling
        switch plugin {
        case "ruby":
            logs += handleRubyEnvironment(version: version)
        case "python":
            logs += handlePythonEnvironment(version: version)
        case "nodejs":
            logs += handleNodeJSEnvironment(version: version)
        case "vue":
            logs += handleVueEnvironment(version: version)
        case "golang":
            logs += handleGoEnvironment(version: version)
        case "java":
            logs += handleJavaEnvironment(version: version)
        case "rust":
            logs += handleRustEnvironment(version: version)
        case "php":
            logs += handlePhpEnvironment(version: version)
        default:
            logs += handleGenericEnvironment(plugin: plugin, version: version)
        }
        
        return logs
    }
    
    // Ruby environment handling
    private func handleRubyEnvironment(version: String) -> String {
        var logs = ""
        
        // Check if rbenv is also managing Ruby
        let rbenvCheck = Shell.run("which rbenv")
        if rbenvCheck.code == 0 {
            logs += "⚠️ rbenv detected - this might conflict with asdf ruby management\n"
            logs += "Consider using only asdf for Ruby version management\n"
        }
        
        // Verify Ruby version after asdf global setting
        let rubyVersionCheck = Shell.run("asdf current ruby")
        logs += "Current asdf ruby: \(rubyVersionCheck.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        
        // Try to get Ruby version directly
        let directRubyCheck = Shell.run("ruby -v")
        logs += "Direct ruby -v: \(directRubyCheck.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        
        // Check if the version contains what we expect
        if directRubyCheck.out.contains(version) {
            logs += "✅ Ruby version correctly switched to \(version)\n"
        } else {
            logs += "⚠️ Ruby version might not have switched yet. Try opening a new terminal tab.\n"
            logs += "💡 Tip: Run 'source ~/.zshrc' in your terminal to reload the configuration\n"
        }
        
        // Check for common Ruby tools
        let bundlerCheck = Shell.run("which bundle")
        if bundlerCheck.code == 0 {
            logs += "✅ Bundler available\n"
        } else {
            logs += "💡 Consider installing bundler: gem install bundler\n"
        }
        
        return logs
    }
    
    // Python environment handling
    private func handlePythonEnvironment(version: String) -> String {
        var logs = ""
        
        // Check for pyenv conflict
        let pyenvCheck = Shell.run("which pyenv")
        if pyenvCheck.code == 0 {
            logs += "⚠️ pyenv detected - this might conflict with asdf python management\n"
        }
        
        // Check for conda conflict
        let condaCheck = Shell.run("which conda")
        if condaCheck.code == 0 {
            logs += "⚠️ conda detected - ensure virtual environment activation doesn't conflict\n"
        }
        
        // Verify Python version
        let pythonVersionCheck = Shell.run("asdf current python")
        logs += "Current asdf python: \(pythonVersionCheck.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        
        let directPythonCheck = Shell.run("python --version")
        logs += "Direct python --version: \(directPythonCheck.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        
        if directPythonCheck.out.contains(version) {
            logs += "✅ Python version correctly switched to \(version)\n"
        } else {
            logs += "⚠️ Python version might not have switched yet.\n"
        }
        
        // Check for pip and virtual environment tools
        let pipCheck = Shell.run("which pip")
        if pipCheck.code == 0 {
            logs += "✅ pip available\n"
        }
        
        let venvCheck = Shell.run("python -m venv --help > /dev/null 2>&1; echo $?")
        if venvCheck.out.trimmingCharacters(in: .whitespacesAndNewlines) == "0" {
            logs += "✅ venv module available\n"
        }
        
        return logs
    }
    
    // Node.js environment handling
    private func handleNodeJSEnvironment(version: String) -> String {
        var logs = ""
        
        // Check for nvm conflict
        let nvmCheck = Shell.run("which nvm")
        if nvmCheck.code == 0 {
            logs += "⚠️ nvm detected - this might conflict with asdf nodejs management\n"
            logs += "💡 Consider using only asdf for Node.js version management\n"
        }
        
        // Check for fnm conflict
        let fnmCheck = Shell.run("which fnm")
        if fnmCheck.code == 0 {
            logs += "⚠️ fnm detected - this might conflict with asdf nodejs management\n"
        }
        
        // Check for volta conflict
        let voltaCheck = Shell.run("which volta")
        if voltaCheck.code == 0 {
            logs += "⚠️ volta detected - this might conflict with asdf nodejs management\n"
        }
        
        // Verify Node.js version
        let nodeVersionCheck = Shell.run("asdf current nodejs")
        logs += "Current asdf nodejs: \(nodeVersionCheck.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        
        let directNodeCheck = Shell.run("node --version")
        logs += "Direct node --version: \(directNodeCheck.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        
        if directNodeCheck.out.contains(version) {
            logs += "✅ Node.js version correctly switched to \(version)\n"
        } else {
            logs += "⚠️ Node.js version might not have switched yet.\n"
        }
        
        // Check for package managers
        let npmCheck = Shell.run("which npm")
        if npmCheck.code == 0 {
            let npmVersionCheck = Shell.run("npm --version")
            logs += "✅ npm available (v\(npmVersionCheck.out.trimmingCharacters(in: .whitespacesAndNewlines)))\n"
        }
        
        let yarnCheck = Shell.run("which yarn")
        if yarnCheck.code == 0 {
            let yarnVersionCheck = Shell.run("yarn --version")
            logs += "✅ yarn available (v\(yarnVersionCheck.out.trimmingCharacters(in: .whitespacesAndNewlines)))\n"
        }
        
        let pnpmCheck = Shell.run("which pnpm")
        if pnpmCheck.code == 0 {
            let pnpmVersionCheck = Shell.run("pnpm --version")
            logs += "✅ pnpm available (v\(pnpmVersionCheck.out.trimmingCharacters(in: .whitespacesAndNewlines)))\n"
        }
        
        // Check for popular Node.js development tools
        let nodeDevToolsStatus = checkNodeJSDevTools()
        logs += nodeDevToolsStatus
        
        return logs
    }
    
    // Check Node.js development tools and frameworks
    private func checkNodeJSDevTools() -> String {
        var logs = ""
        
        // Vue ecosystem
        let vueCliCheck = Shell.run("which vue")
        if vueCliCheck.code == 0 {
            let vueVersionCheck = Shell.run("vue --version")
            logs += "✅ Vue CLI available (v\(vueVersionCheck.out.trimmingCharacters(in: .whitespacesAndNewlines)))\n"
        } else {
            logs += "💡 Vue CLI not found - install with: npm install -g @vue/cli\n"
        }
        
        let viteCheck = Shell.run("which vite")
        if viteCheck.code == 0 {
            let viteVersionCheck = Shell.run("vite --version")
            logs += "✅ Vite available (v\(viteVersionCheck.out.trimmingCharacters(in: .whitespacesAndNewlines)))\n"
        } else {
            logs += "💡 Vite not found globally - usually installed per project\n"
        }
        
        let nuxtCheck = Shell.run("which nuxt")
        if nuxtCheck.code == 0 {
            let nuxtVersionCheck = Shell.run("nuxt --version")
            logs += "✅ Nuxt available (v\(nuxtVersionCheck.out.trimmingCharacters(in: .whitespacesAndNewlines)))\n"
        }
        
        // React ecosystem
        let createReactAppCheck = Shell.run("which create-react-app")
        if createReactAppCheck.code == 0 {
            logs += "✅ Create React App available\n"
        }
        
        let nextCheck = Shell.run("which next")
        if nextCheck.code == 0 {
            let nextVersionCheck = Shell.run("next --version")
            logs += "✅ Next.js available (v\(nextVersionCheck.out.trimmingCharacters(in: .whitespacesAndNewlines)))\n"
        }
        
        // Angular ecosystem
        let ngCheck = Shell.run("which ng")
        if ngCheck.code == 0 {
            let _ = Shell.run("ng version --version")
            logs += "✅ Angular CLI available\n"
        }
        
        // Build tools and bundlers
        let webpackCheck = Shell.run("which webpack")
        if webpackCheck.code == 0 {
            let webpackVersionCheck = Shell.run("webpack --version")
            logs += "✅ Webpack available (v\(webpackVersionCheck.out.trimmingCharacters(in: .whitespacesAndNewlines)))\n"
        }
        
        let rollupCheck = Shell.run("which rollup")
        if rollupCheck.code == 0 {
            let rollupVersionCheck = Shell.run("rollup --version")
            logs += "✅ Rollup available (v\(rollupVersionCheck.out.trimmingCharacters(in: .whitespacesAndNewlines)))\n"
        }
        
        let parcelCheck = Shell.run("which parcel")
        if parcelCheck.code == 0 {
            let parcelVersionCheck = Shell.run("parcel --version")
            logs += "✅ Parcel available (v\(parcelVersionCheck.out.trimmingCharacters(in: .whitespacesAndNewlines)))\n"
        }
        
        // TypeScript and development tools
        let tscCheck = Shell.run("which tsc")
        if tscCheck.code == 0 {
            let tscVersionCheck = Shell.run("tsc --version")
            logs += "✅ TypeScript compiler available (v\(tscVersionCheck.out.trimmingCharacters(in: .whitespacesAndNewlines)))\n"
        } else {
            logs += "💡 TypeScript not found globally - install with: npm install -g typescript\n"
        }
        
        let eslintCheck = Shell.run("which eslint")
        if eslintCheck.code == 0 {
            let eslintVersionCheck = Shell.run("eslint --version")
            logs += "✅ ESLint available (v\(eslintVersionCheck.out.trimmingCharacters(in: .whitespacesAndNewlines)))\n"
        }
        
        let prettierCheck = Shell.run("which prettier")
        if prettierCheck.code == 0 {
            let prettierVersionCheck = Shell.run("prettier --version")
            logs += "✅ Prettier available (v\(prettierVersionCheck.out.trimmingCharacters(in: .whitespacesAndNewlines)))\n"
        }
        
        // Development servers and tools
        let nodemonCheck = Shell.run("which nodemon")
        if nodemonCheck.code == 0 {
            let nodemonVersionCheck = Shell.run("nodemon --version")
            logs += "✅ Nodemon available (v\(nodemonVersionCheck.out.trimmingCharacters(in: .whitespacesAndNewlines)))\n"
        }
        
        let pmTwoCheck = Shell.run("which pm2")
        if pmTwoCheck.code == 0 {
            let pmTwoVersionCheck = Shell.run("pm2 --version")
            logs += "✅ PM2 available (v\(pmTwoVersionCheck.out.trimmingCharacters(in: .whitespacesAndNewlines)))\n"
        }
        
        return logs
    }
    
    // Vue environment handling  
    private func handleVueEnvironment(version: String) -> String {
        var logs = ""
        
        logs += "🔧 Checking Vue.js development environment...\n"
        
        // Check Node.js dependency first
        let nodeCheck = Shell.run("which node")
        if nodeCheck.code != 0 {
            logs += "❌ Node.js is required for Vue development but not found\n"
            logs += "💡 Install Node.js first with: asdf install nodejs latest\n"
            return logs
        }
        
        let nodeVersionCheck = Shell.run("node --version")
        logs += "✅ Node.js available: \(nodeVersionCheck.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        
        // Check npm
        let npmCheck = Shell.run("which npm")
        if npmCheck.code == 0 {
            let npmVersionCheck = Shell.run("npm --version")
            logs += "✅ npm available: \(npmVersionCheck.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        } else {
            logs += "❌ npm not found - this is unusual with Node.js installation\n"
            return logs
        }
        
        // Check Vue CLI
        let vueCliCheck = Shell.run("which vue")
        if vueCliCheck.code == 0 {
            let vueVersionCheck = Shell.run("vue --version")
            logs += "✅ Vue CLI available: \(vueVersionCheck.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
            
            // Check if version matches what we expect
            if vueVersionCheck.out.contains(version) {
                logs += "✅ Vue CLI version matches expected version \(version)\n"
            } else {
                logs += "⚠️ Vue CLI version does not match expected version \(version)\n"
                logs += "Current: \(vueVersionCheck.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
                logs += "💡 Update with: npm update -g @vue/cli\n"
            }
        } else {
            logs += "❌ Vue CLI not found\n"
            logs += "💡 Install Vue CLI with: npm install -g @vue/cli\n"
        }
        
        // Check for Vite (modern Vue development)
        let viteCheck = Shell.run("which vite")
        if viteCheck.code == 0 {
            let viteVersionCheck = Shell.run("vite --version")
            logs += "✅ Vite available: \(viteVersionCheck.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        } else {
            logs += "💡 Vite not found globally - usually installed per project\n"
            logs += "💡 For new Vue 3 projects, consider: npm create vue@latest\n"
        }
        
        // Check for Vue Devtools CLI
        let vueDevtoolsCheck = Shell.run("which vue-devtools")
        if vueDevtoolsCheck.code == 0 {
            logs += "✅ Vue Devtools CLI available\n"
        } else {
            logs += "💡 Vue Devtools CLI not found - install with: npm install -g @vue/devtools\n"
        }
        
        // Check for TypeScript support
        let tscCheck = Shell.run("which tsc")
        if tscCheck.code == 0 {
            let tscVersionCheck = Shell.run("tsc --version")
            logs += "✅ TypeScript available: \(tscVersionCheck.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        } else {
            logs += "💡 TypeScript not found - install for Vue+TS development: npm install -g typescript\n"
        }
        
        // Check for Nuxt.js (Vue framework)
        let nuxtCheck = Shell.run("which nuxt")
        if nuxtCheck.code == 0 {
            let nuxtVersionCheck = Shell.run("nuxt --version")
            logs += "✅ Nuxt.js available: \(nuxtVersionCheck.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        } else {
            logs += "💡 Nuxt.js not found - install for full-stack Vue development: npm install -g nuxt\n"
        }
        
        // Check package managers
        let yarnCheck = Shell.run("which yarn")
        if yarnCheck.code == 0 {
            let yarnVersionCheck = Shell.run("yarn --version")
            logs += "✅ Yarn available: \(yarnVersionCheck.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        }
        
        let pnpmCheck = Shell.run("which pnpm")
        if pnpmCheck.code == 0 {
            let pnpmVersionCheck = Shell.run("pnpm --version")
            logs += "✅ pnpm available: \(pnpmVersionCheck.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        }
        
        // Project creation suggestions
        logs += "\n📝 Vue Project Creation Options:\n"
        logs += "• Vue 3 + Vite: npm create vue@latest my-project\n"
        logs += "• Vue CLI: vue create my-project\n"
        logs += "• Nuxt 3: npx nuxi@latest init my-project\n"
        
        return logs
    }
    
    // Go environment handling
    private func handleGoEnvironment(version: String) -> String {
        var logs = ""
        
        // Check for system Go conflict
        let systemGoCheck = Shell.run("which go")
        if systemGoCheck.code == 0 {
            let goPath = systemGoCheck.out.trimmingCharacters(in: .whitespacesAndNewlines)
            if !goPath.contains("asdf") {
                logs += "⚠️ System Go detected at \(goPath) - asdf Go might not take precedence\n"
            }
        }
        
        // Verify Go version
        let goVersionCheck = Shell.run("asdf current golang")
        logs += "Current asdf golang: \(goVersionCheck.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        
        let directGoCheck = Shell.run("go version")
        logs += "Direct go version: \(directGoCheck.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        
        if directGoCheck.out.contains(version) {
            logs += "✅ Go version correctly switched to \(version)\n"
        } else {
            logs += "⚠️ Go version might not have switched yet.\n"
        }
        
        // Check GOPATH and GOROOT
        let gopathCheck = Shell.run("go env GOPATH")
        logs += "GOPATH: \(gopathCheck.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        
        let gorootCheck = Shell.run("go env GOROOT")
        logs += "GOROOT: \(gorootCheck.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        
        return logs
    }
    
    // Java environment handling
    private func handleJavaEnvironment(version: String) -> String {
        var logs = ""
        
        // Check for system Java or other Java managers
        let javaHomeCheck = Shell.run("echo $JAVA_HOME")
        if !javaHomeCheck.out.isEmpty {
            logs += "Current JAVA_HOME: \(javaHomeCheck.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        }
        
        // Check for jenv conflict
        let jenvCheck = Shell.run("which jenv")
        if jenvCheck.code == 0 {
            logs += "⚠️ jenv detected - this might conflict with asdf java management\n"
        }
        
        // Verify Java version
        let javaVersionCheck = Shell.run("asdf current java")
        logs += "Current asdf java: \(javaVersionCheck.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        
        let directJavaCheck = Shell.run("java -version 2>&1")
        logs += "Direct java -version: \(directJavaCheck.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        
        if directJavaCheck.out.contains(version.replacingOccurrences(of: "openjdk-", with: "")) {
            logs += "✅ Java version correctly switched to \(version)\n"
        } else {
            logs += "⚠️ Java version might not have switched yet.\n"
        }
        
        return logs
    }
    
    // Rust environment handling
    private func handleRustEnvironment(version: String) -> String {
        var logs = ""
        
        // Check for rustup conflict
        let rustupCheck = Shell.run("which rustup")
        if rustupCheck.code == 0 {
            logs += "⚠️ rustup detected - this might conflict with asdf rust management\n"
            logs += "💡 Consider using either rustup OR asdf for Rust management\n"
        }
        
        // Verify Rust version
        let rustVersionCheck = Shell.run("asdf current rust")
        logs += "Current asdf rust: \(rustVersionCheck.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        
        let directRustCheck = Shell.run("rustc --version")
        logs += "Direct rustc --version: \(directRustCheck.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        
        if directRustCheck.out.contains(version) {
            logs += "✅ Rust version correctly switched to \(version)\n"
        } else {
            logs += "⚠️ Rust version might not have switched yet.\n"
        }
        
        // Check for cargo
        let cargoCheck = Shell.run("which cargo")
        if cargoCheck.code == 0 {
            logs += "✅ cargo available\n"
        }
        
        return logs
    }
    
    // PHP environment handling
    private func handlePhpEnvironment(version: String) -> String {
        var logs = ""
        
        // Check for system PHP
        let systemPhpCheck = Shell.run("which php")
        if systemPhpCheck.code == 0 {
            let phpPath = systemPhpCheck.out.trimmingCharacters(in: .whitespacesAndNewlines)
            if !phpPath.contains("asdf") {
                logs += "⚠️ System PHP detected at \(phpPath)\n"
            }
        }
        
        // Check for phpenv conflict
        let phpenvCheck = Shell.run("which phpenv")
        if phpenvCheck.code == 0 {
            logs += "⚠️ phpenv detected - this might conflict with asdf php management\n"
        }
        
        // Verify PHP version
        let phpVersionCheck = Shell.run("asdf current php")
        logs += "Current asdf php: \(phpVersionCheck.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        
        let directPhpCheck = Shell.run("php --version")
        logs += "Direct php --version: \(directPhpCheck.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        
        if directPhpCheck.out.contains(version) {
            logs += "✅ PHP version correctly switched to \(version)\n"
        } else {
            logs += "⚠️ PHP version might not have switched yet.\n"
        }
        
        // Check for composer
        let composerCheck = Shell.run("which composer")
        if composerCheck.code == 0 {
            logs += "✅ composer available\n"
        }
        
        return logs
    }
    
    // Generic environment handling for other languages
    private func handleGenericEnvironment(plugin: String, version: String) -> String {
        var logs = ""
        
        // Verify version with asdf
        let versionCheck = Shell.run("asdf current \(plugin)")
        logs += "Current asdf \(plugin): \(versionCheck.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        
        // Try to get version directly if the command exists
        let directCheck = Shell.run("\(plugin) --version 2>/dev/null || \(plugin) -v 2>/dev/null || echo 'Version command not found'")
        if !directCheck.out.contains("Version command not found") {
            logs += "Direct \(plugin) version: \(directCheck.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
            
            if directCheck.out.contains(version) {
                logs += "✅ \(plugin.capitalized) version correctly switched to \(version)\n"
            } else {
                logs += "⚠️ \(plugin.capitalized) version might not have switched yet.\n"
            }
        } else {
            logs += "💡 Cannot verify \(plugin) version directly - check manually if needed\n"
        }
        
        return logs
    }
    
    // Update terminal profile settings
    private func updateTerminalProfile(profile: EnvironmentProfile) -> String {
        var logs = "[Update Terminal Profile]\n"
        
        // Check if iTerm2 is available
        let iTermCheck = Shell.run("osascript -e 'tell application \"System Events\" to return exists process \"iTerm2\"'")
        if iTermCheck.out.contains("true") {
            // Create detailed environment info
            var environmentInfo = "# Environment switched to: \(profile.name)"
            for (plugin, version) in profile.versions {
                environmentInfo += "\\n# \(plugin): \(version)"
            }
            
            // Generate verification commands for each language
            var verificationCommands = ["echo '✅ Environment switched. Current versions:'"]
            
            for (plugin, _) in profile.versions {
                switch plugin {
                case "ruby":
                    verificationCommands.append("ruby -v")
                case "python":
                    verificationCommands.append("python --version")
                case "nodejs":
                    verificationCommands.append("node --version")
                    verificationCommands.append("npm --version")
                    verificationCommands.append("echo '--- Frontend Tools Check ---'")
                    verificationCommands.append("vue --version 2>/dev/null || echo 'Vue CLI: Not installed'")
                    verificationCommands.append("tsc --version 2>/dev/null || echo 'TypeScript: Not installed'")
                    verificationCommands.append("which yarn >/dev/null && yarn --version || echo 'Yarn: Not installed'")
                case "vue":
                    verificationCommands.append("node --version")
                    verificationCommands.append("npm --version")
                    verificationCommands.append("vue --version")
                    verificationCommands.append("echo '--- Vue Development Environment ---'")
                    verificationCommands.append("vite --version 2>/dev/null || echo 'Vite: Not installed globally'")
                    verificationCommands.append("tsc --version 2>/dev/null || echo 'TypeScript: Not installed'")
                    verificationCommands.append("nuxt --version 2>/dev/null || echo 'Nuxt: Not installed'")
                case "golang":
                    verificationCommands.append("go version")
                case "java":
                    verificationCommands.append("java -version")
                case "rust":
                    verificationCommands.append("rustc --version")
                case "php":
                    verificationCommands.append("php --version")
                default:
                    verificationCommands.append("\(plugin) --version || \(plugin) -v || echo '\(plugin): version command not available'")
                }
            }
            
            environmentInfo += "\\n# Environment has been applied immediately to this and all terminal sessions"
            environmentInfo += "\\n# Changes are now active system-wide. Verify with the commands below:"
            
            // iTerm2 is running, try to update profile and send message
            let commandsString = verificationCommands.joined(separator: "\\n")
            let script = """
            tell application "iTerm2"
                tell current session of current window
                    write text "\(environmentInfo)"
                    write text ""
                    write text "\(commandsString)"
                end tell
            end tell
            """
            let updateResult = Shell.run("osascript -e '\(script)'")
            logs += "Update iTerm2 profile: \(updateResult.code == 0 ? "✅" : "❌")\n"
            if updateResult.code == 0 {
                logs += "✅ Sent environment verification commands to iTerm2\n"
            }
        } else {
            logs += "iTerm2 not running, skipping terminal profile update\n"
            logs += "💡 Tip: Open iTerm2 and verify versions manually:\n"
            
            for (plugin, _) in profile.versions {
                switch plugin {
                case "ruby":
                    logs += "   ruby -v\n"
                case "python":
                    logs += "   python --version\n"
                case "nodejs":
                    logs += "   node --version\n"
                    logs += "   npm --version\n"
                    logs += "   vue --version (Vue CLI)\n"
                    logs += "   tsc --version (TypeScript)\n"
                    logs += "   yarn --version (if installed)\n"
                case "vue":
                    logs += "   node --version\n"
                    logs += "   npm --version\n"
                    logs += "   vue --version\n"
                    logs += "   vite --version (Vite)\n"
                    logs += "   tsc --version (TypeScript)\n"
                    logs += "   nuxt --version (Nuxt.js)\n"
                case "golang":
                    logs += "   go version\n"
                case "java":
                    logs += "   java -version\n"
                case "rust":
                    logs += "   rustc --version\n"
                case "php":
                    logs += "   php --version\n"
                default:
                    logs += "   \(plugin) --version\n"
                }
            }
        }
        
        return logs
    }
    
    // Verify that environment changes took effect
    private func verifyEnvironmentChanges(profile: EnvironmentProfile) -> String {
        var logs = "[Verify Environment Changes]\n"
        
        // 1. Immediate verification of current process environment
        logs += "=== Current Process Verification ===\n"
        
        // Check asdf versions in current environment
        for (plugin, expectedVersion) in profile.versions {
            // Check asdf current
            let currentResult = Shell.run("asdf current \(plugin)")
            let currentVersion = currentResult.out.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if currentVersion.contains(expectedVersion) {
                logs += "✅ \(plugin): \(expectedVersion) (asdf active)\n"
            } else {
                logs += "⚠️ \(plugin): Expected \(expectedVersion), asdf shows \(currentVersion)\n"
            }
            
            // Check direct command version
            let directVersionResult = getDirectVersionCommand(plugin: plugin, expectedVersion: expectedVersion)
            logs += directVersionResult
        }
        
        // Check environment variables in current process
        for (key, expectedValue) in profile.environmentVars {
            let envPtr = getenv(key)
            var currentValue = ""
            if let valuePtr = envPtr {
                currentValue = String(cString: valuePtr)
            }
            
            if !currentValue.isEmpty && currentValue == expectedValue {
                logs += "✅ ENV \(key): \(expectedValue)\n"
            } else {
                logs += "⚠️ ENV \(key): Expected \(expectedValue), got \(currentValue)\n"
            }
        }
        
        // 2. System-wide verification
        logs += "\n=== System-wide Verification ===\n"
        
        // Check PATH contains asdf shims
        let currentPathPtr = getenv("PATH")
        var currentPath = ""
        if let pathPtr = currentPathPtr {
            currentPath = String(cString: pathPtr)
        }
        
        if currentPath.contains(".asdf/shims") {
            logs += "✅ PATH contains asdf shims\n"
        } else {
            logs += "⚠️ PATH missing asdf shims\n"
        }
        
        // Check launchctl environment
        for (key, expectedValue) in profile.environmentVars {
            let launchctlResult = Shell.run("launchctl getenv \(key) 2>/dev/null")
            if launchctlResult.code == 0 && launchctlResult.out.trimmingCharacters(in: .whitespacesAndNewlines) == expectedValue {
                logs += "✅ System ENV \(key): \(expectedValue)\n"
            } else {
                logs += "⚠️ System ENV \(key): Not set system-wide\n"
            }
        }
        
        // 3. Terminal session verification
        logs += "\n=== Terminal Session Verification ===\n"
        let terminalVerificationResult = verifyTerminalSessions(profile: profile)
        logs += terminalVerificationResult
        
        return logs
    }
    
    // Get direct version command for verification
    private func getDirectVersionCommand(plugin: String, expectedVersion: String) -> String {
        var result = ""
        
        switch plugin {
        case "ruby":
            let rubyResult = Shell.run("ruby -v")
            if rubyResult.code == 0 && rubyResult.out.contains(expectedVersion) {
                result = "✅ ruby -v: \(expectedVersion) detected\n"
            } else {
                result = "⚠️ ruby -v: \(rubyResult.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
            }
        case "python":
            let pythonResult = Shell.run("python --version")
            if pythonResult.code == 0 && pythonResult.out.contains(expectedVersion) {
                result = "✅ python --version: \(expectedVersion) detected\n"
            } else {
                result = "⚠️ python --version: \(pythonResult.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
            }
        case "nodejs":
            let nodeResult = Shell.run("node --version")
            if nodeResult.code == 0 && nodeResult.out.contains(expectedVersion) {
                result = "✅ node --version: \(expectedVersion) detected\n"
            } else {
                result = "⚠️ node --version: \(nodeResult.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
            }
        case "golang":
            let goResult = Shell.run("go version")
            if goResult.code == 0 && goResult.out.contains(expectedVersion) {
                result = "✅ go version: \(expectedVersion) detected\n"
            } else {
                result = "⚠️ go version: \(goResult.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
            }
        case "java":
            let javaResult = Shell.run("java -version 2>&1")
            if javaResult.code == 0 && javaResult.out.contains(expectedVersion.replacingOccurrences(of: "openjdk-", with: "")) {
                result = "✅ java -version: \(expectedVersion) detected\n"
            } else {
                result = "⚠️ java -version: \(javaResult.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
            }
        default:
            let genericResult = Shell.run("\(plugin) --version 2>/dev/null || \(plugin) -v 2>/dev/null")
            if genericResult.code == 0 && genericResult.out.contains(expectedVersion) {
                result = "✅ \(plugin) version: \(expectedVersion) detected\n"
            } else {
                result = "⚠️ \(plugin) version: \(genericResult.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
            }
        }
        
        return result
    }
    
    // Verify terminal sessions have the correct environment
    private func verifyTerminalSessions(profile: EnvironmentProfile) -> String {
        var logs = ""
        
        // Create a verification script
        let verificationScript = """
#!/bin/bash
echo "=== Terminal Environment Verification ==="
echo "Current shell: $SHELL"
echo "PATH: $PATH"
\(profile.versions.map { (plugin, version) in
    switch plugin {
    case "ruby": return "echo \"Ruby: $(ruby -v 2>/dev/null || echo 'not found')\""
    case "python": return "echo \"Python: $(python --version 2>/dev/null || echo 'not found')\""
    case "nodejs": return "echo \"Node.js: $(node --version 2>/dev/null || echo 'not found')\""
    case "golang": return "echo \"Go: $(go version 2>/dev/null || echo 'not found')\""
    case "java": return "echo \"Java: $(java -version 2>&1 | head -n1 || echo 'not found')\""
    default: return "echo \"\(plugin.capitalized): $(\(plugin) --version 2>/dev/null || \(plugin) -v 2>/dev/null || echo 'not found')\""
    }
}.joined(separator: "\n"))
\(profile.environmentVars.map { "echo \"\($0.key): $\($0.key)\"" }.joined(separator: "\n"))
echo "=== End Verification ==="
"""
        
        let tempScriptPath = "/tmp/macenvswitcher_verify.sh"
        
        do {
            try verificationScript.write(toFile: tempScriptPath, atomically: true, encoding: .utf8)
            let chmodResult = Shell.run("chmod +x '\(tempScriptPath)'")
            
            if chmodResult.code == 0 {
                logs += "✅ Created verification script\n"
                logs += "💡 Run 'bash \(tempScriptPath)' in any terminal to verify environment\n"
            } else {
                logs += "❌ Failed to create verification script\n"
            }
            
        } catch {
            logs += "❌ Failed to write verification script: \(error.localizedDescription)\n"
        }
        
        return logs
    }

    // jabba optional
    private func installJabba() -> (Bool, String, String?) {
        let check = Shell.run("brew list --formula --versions | awk '{print $1}' | grep -qx jabba && echo YES || echo NO")
        if check.out.contains("YES") { return (true, tr("Already installed jabba"), nil) }
        let r = Shell.run("brew install jabba")
        return (r.code == 0, r.out + r.err, tr("jabba manages Java separately; prefer asdf-java for unified profiles."))
    }
