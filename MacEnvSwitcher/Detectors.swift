
import Foundation

struct CheckResult { let ok: Bool; let log: String; let tip: String? }

struct ConflictInfo {
    let tool: String
    let managers: [String]
    let recommended: String
    let pathConflicts: [String]
    let envConflicts: [String: [String]]
}

final class Detectors {
    func check(_ t: TaskID) -> CheckResult {
        switch t {
        case .clt: return clt()
        case .brew: return brew()
        case .iterm2: return iterm2()
        case .ohMyBash: return ohMyBash()
        case .python3: return python3()
        case .ruby: return ruby()
        case .fastlane: return fastlane()
        case .xcode: return xcode()
        case .asdf: return asdf()
        case .nodejs: return nodejs()
        case .golang: return golang()
        case .java: return java()
        case .pnpm: return pnpm()
        case .yarn: return yarn()
        case .maven: return maven()
        case .gradle: return gradle()
        case .pythonAsdf: return pythonAsdf()
        case .rust: return rust()
        case .jabba: return jabba()
        }
    }

    private func clt() -> CheckResult { let r = Shell.run("xcode-select -p"); let ok = (r.code == 0) && !r.out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty; return .init(ok: ok, log: r.out + r.err, tip: ok ? nil : tr("CLT not installed. Use ‘xcode-select --install’.")) }
    private func brew() -> CheckResult { let r = Shell.run("brew --version"); return .init(ok: r.code == 0, log: r.out + r.err, tip: r.code == 0 ? nil : tr("Homebrew not found")) }
    private func iterm2() -> CheckResult { let r1 = Shell.run("[ -d /Applications/iTerm.app ] && echo YES || echo NO"); if r1.out.contains("YES") { return .init(ok: true, log: "Found /Applications/iTerm.app", tip: nil) }; let r2 = Shell.run("brew list --cask --versions | awk '{print $1}' | grep -qx iterm2 && echo YES || echo NO"); return .init(ok: r2.out.contains("YES"), log: r1.out + r2.out, tip: r2.out.contains("YES") ? nil : tr("iTerm2 not installed")) }
    private func ohMyBash() -> CheckResult { 
        // 检查标准路径和共享路径
        let r1 = Shell.run("[ -d \"$HOME/.oh-my-zsh\" ] && echo YES || echo NO")
        let r2 = Shell.run("[ -d \"/opt/shared_env/oh-my-zsh\" ] && echo YES || echo NO")
        let r3 = Shell.run("grep -q 'oh-my-zsh' ~/.zshrc 2>/dev/null && echo YES || echo NO")
        let ok = r1.out.contains("YES") || r2.out.contains("YES") || r3.out.contains("YES")
        let log = "Standard path: " + r1.out + "Shared path: " + r2.out + "Config check: " + r3.out + r1.err + r2.err
        return .init(ok: ok, log: log, tip: ok ? nil : tr("oh-my-zsh not installed"))
    }
    private func python3() -> CheckResult { 
        let r = Shell.run("python3 --version 2>&1")
        let r2 = Shell.run("which python3 2>&1")
        let ok = r.code == 0 || !r.out.isEmpty || !r2.out.isEmpty
        let log = "Version: " + r.out + r.err + "\nPath: " + r2.out
        return .init(ok: ok, log: log, tip: ok ? nil : tr("Python3 not found"))
    }
    private func ruby() -> CheckResult { let r = Shell.run("ruby --version"); return .init(ok: r.code == 0, log: r.out + r.err, tip: r.code == 0 ? nil : tr("Ruby not found")) }
    private func fastlane() -> CheckResult { let r = Shell.run("fastlane --version | head -n1"); return .init(ok: r.code == 0, log: r.out + r.err, tip: r.code == 0 ? nil : tr("fastlane not found")) }
    private func xcode() -> CheckResult { let r1 = Shell.run("[ -d /Applications/Xcode.app ] && echo YES || echo NO"); var ok = r1.out.contains("YES"); var log = r1.out; if ok { let r2 = Shell.run("xcodebuild -version"); ok = r2.code == 0; log += "\n" + r2.out + r2.err; let tip = ok ? nil : tr("If Xcode installed, run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"); return .init(ok: ok, log: log, tip: tip) } ; return .init(ok: false, log: log, tip: tr("Xcode not installed")) }

    private func asdf() -> CheckResult { let r = Shell.run("command -v asdf >/dev/null 2>&1; echo $?"); let ok = r.out.trimmingCharacters(in: .whitespacesAndNewlines) == "0"; let v = Shell.run("asdf --version || true"); return .init(ok: ok, log: v.out + v.err, tip: ok ? nil : tr("Install asdf via Homebrew, then add to shell rc")) }

    private func nodejs() -> CheckResult { let r1 = Shell.run("node -v || true"); let r2 = Shell.run("asdf list nodejs || true"); let r3 = Shell.run("asdf current nodejs || true"); let ok = (!r1.out.isEmpty) || (!r2.out.isEmpty); let log = "node -v: \(r1.out)\ninstalled:\n\(r2.out)\ncurrent:\n\(r3.out)"; return .init(ok: ok, log: log, tip: ok ? tr("Use asdf to manage versions") : tr("Use asdf plugin 'nodejs'")) }
    private func golang() -> CheckResult { let r1 = Shell.run("go version || true"); let r2 = Shell.run("asdf list golang || true"); let r3 = Shell.run("asdf current golang || true"); let ok = (!r1.out.isEmpty) || (!r2.out.isEmpty); let log = "go: \(r1.out)\ninstalled:\n\(r2.out)\ncurrent:\n\(r3.out)"; return .init(ok: ok, log: log, tip: ok ? tr("Use asdf to manage versions") : tr("Use asdf plugin 'golang'")) }
    private func java() -> CheckResult { let r1 = Shell.run("java -version 2>&1 | head -n2 || true"); let r2 = Shell.run("asdf list java || true"); let r3 = Shell.run("asdf current java || true"); let ok = (!r1.out.isEmpty) || (!r2.out.isEmpty); let log = "java:\n\(r1.out)\ninstalled:\n\(r2.out)\ncurrent:\n\(r3.out)"; return .init(ok: ok, log: log, tip: ok ? tr("Use asdf to install/switch Java") : tr("Use asdf plugin 'java' (Temurin/Corretto...)")) }

    private func pnpm() -> CheckResult { let r1 = Shell.run("pnpm -v || true"); let r2 = Shell.run("asdf list pnpm || true"); let ok = (!r1.out.isEmpty)||(!r2.out.isEmpty); let log = "pnpm: \(r1.out)\n\(r2.out)"; return .init(ok: ok, log: log, tip: ok ? nil : tr("Use asdf plugin 'pnpm' (requires Node.js)")) }
    private func yarn() -> CheckResult { let r1 = Shell.run("yarn -v || true"); let r2 = Shell.run("asdf list yarn || true"); let ok = (!r1.out.isEmpty)||(!r2.out.isEmpty); let log = "yarn: \(r1.out)\n\(r2.out)"; return .init(ok: ok, log: log, tip: ok ? nil : tr("Use asdf plugin 'yarn' (requires Node.js)")) }
    private func maven() -> CheckResult { let r1 = Shell.run("mvn -v | head -n1 || true"); let r2 = Shell.run("asdf list maven || true"); let ok = (!r1.out.isEmpty)||(!r2.out.isEmpty); let log = "maven: \(r1.out)\n\(r2.out)"; return .init(ok: ok, log: log, tip: ok ? nil : tr("Use asdf plugin 'maven'")) }
    private func gradle() -> CheckResult { let r1 = Shell.run("gradle -v | head -n1 || true"); let r2 = Shell.run("asdf list gradle || true"); let ok = (!r1.out.isEmpty)||(!r2.out.isEmpty); let log = "gradle: \(r1.out)\n\(r2.out)"; return .init(ok: ok, log: log, tip: ok ? nil : tr("Use asdf plugin 'gradle'")) }
    private func pythonAsdf() -> CheckResult { let r1 = Shell.run("python --version 2>&1 || true"); let r2 = Shell.run("asdf list python || true"); let r3 = Shell.run("asdf current python || true"); let ok = (!r1.out.isEmpty)||(!r2.out.isEmpty); let log = "python: \(r1.out)\ninstalled:\n\(r2.out)\ncurrent:\n\(r3.out)"; return .init(ok: ok, log: log, tip: ok ? tr("Managed by asdf") : tr("Use asdf plugin 'python'")) }
    private func rust() -> CheckResult { let r1 = Shell.run("rustc --version || true"); let r2 = Shell.run("asdf list rust || true"); let ok = (!r1.out.isEmpty)||(!r2.out.isEmpty); let log = "rust: \(r1.out)\n\(r2.out)"; return .init(ok: ok, log: log, tip: ok ? tr("Managed by asdf") : tr("Use asdf plugin 'rust' (uses rustup)")) }
    private func jabba() -> CheckResult { let r1 = Shell.run("jabba --version || true"); let ok = !r1.out.isEmpty; return .init(ok: ok, log: r1.out + r1.err, tip: ok ? tr("jabba installed (optional)") : tr("Install jabba via Homebrew if needed")) }
    
    // MARK: - Enhanced Conflict Detection and PATH Analysis
    
    /// 检查版本管理器冲突
    func checkVersionManagerConflicts() -> [ConflictInfo] {
        var conflicts: [ConflictInfo] = []
        
        // Node.js 冲突检查
        let nodeConflict = checkNodeJSConflicts()
        if !nodeConflict.managers.isEmpty {
            conflicts.append(nodeConflict)
        }
        
        // Python 冲突检查
        let pythonConflict = checkPythonConflicts()
        if !pythonConflict.managers.isEmpty {
            conflicts.append(pythonConflict)
        }
        
        // Ruby 冲突检查
        let rubyConflict = checkRubyConflicts()
        if !rubyConflict.managers.isEmpty {
            conflicts.append(rubyConflict)
        }
        
        // Java 冲突检查
        let javaConflict = checkJavaConflicts()
        if !javaConflict.managers.isEmpty {
            conflicts.append(javaConflict)
        }
        
        return conflicts
    }
    
    /// 检查PATH优先级
    func checkPATHPriority() -> [String: [String]] {
        let pathResult = Shell.run("echo $PATH")
        let paths = pathResult.out.split(separator: ":").map(String.init)
        
        var pathAnalysis: [String: [String]] = [:]
        
        // 检查关键工具的PATH顺序
        let toolPaths = [
            "asdf": ["/opt/homebrew/bin/asdf", "/usr/local/bin/asdf"],
            "brew": ["/opt/homebrew/bin", "/usr/local/bin"],
            "python": ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"],
            "node": ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"],
            "ruby": ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"],
            "java": ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"]
        ]
        
        for (tool, expectedPaths) in toolPaths {
            var foundPaths: [String] = []
            for path in paths {
                if expectedPaths.contains(path) || path.contains(tool) {
                    foundPaths.append(path)
                }
            }
            if !foundPaths.isEmpty {
                pathAnalysis[tool] = foundPaths
            }
        }
        
        return pathAnalysis
    }
    
    /// 检查环境变量冲突
    func checkEnvironmentVariableConflicts() -> [String: [String]] {
        var conflicts: [String: [String]] = [:]
        
        // 检查Java相关环境变量
        let javaVars = ["JAVA_HOME", "JDK_HOME", "JAVA_OPTS"]
        for javaVar in javaVars {
            let result = Shell.run("echo $\(javaVar)")
            let value = result.out.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                conflicts[javaVar] = [value]
            }
        }
        
        // 检查Python相关环境变量
        let pythonVars = ["PYTHONPATH", "PYTHONHOME", "VIRTUAL_ENV"]
        for pythonVar in pythonVars {
            let result = Shell.run("echo $\(pythonVar)")
            let value = result.out.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                conflicts[pythonVar] = [value]
            }
        }
        
        // 检查Node.js相关环境变量
        let nodeVars = ["NODE_PATH", "NODE_ENV", "NPM_CONFIG_PREFIX"]
        for nodeVar in nodeVars {
            let result = Shell.run("echo $\(nodeVar)")
            let value = result.out.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                conflicts[nodeVar] = [value]
            }
        }
        
        return conflicts
    }
    
    // MARK: - Specific Conflict Checkers
    
    private func checkNodeJSConflicts() -> ConflictInfo {
        var managers: [String] = []
        var pathConflicts: [String] = []
        var envConflicts: [String: [String]] = [:]
        
        // 检查nvm
        let nvmCheck = Shell.run("command -v nvm >/dev/null 2>&1; echo $?")
        let nvmRcCheck = Shell.run("[ -f ~/.nvmrc ] && echo 'nvmrc found' || echo 'no nvmrc'")
        if nvmCheck.out.contains("0") || nvmRcCheck.out.contains("nvmrc found") {
            managers.append("nvm")
            pathConflicts.append("$HOME/.nvm")
        }
        
        // 检查fnm
        let fnmCheck = Shell.run("command -v fnm >/dev/null 2>&1; echo $?")
        if fnmCheck.out.contains("0") {
            managers.append("fnm")
            pathConflicts.append("$HOME/.fnm")
        }
        
        // 检查n
        let nCheck = Shell.run("command -v n >/dev/null 2>&1; echo $?")
        if nCheck.out.contains("0") {
            managers.append("n")
            pathConflicts.append("/usr/local/n")
        }
        
        // 检查asdf nodejs
        let asdfNodeCheck = Shell.run("asdf plugin list | grep -q nodejs && echo 'found' || echo 'not found'")
        if asdfNodeCheck.out.contains("found") {
            managers.append("asdf")
        }
        
        // 检查brew安装的node
        let brewNodeCheck = Shell.run("brew list --formula | grep -q '^node$' && echo 'found' || echo 'not found'")
        if brewNodeCheck.out.contains("found") {
            managers.append("homebrew")
            pathConflicts.append("/opt/homebrew/bin/node")
        }
        
        // 检查NPM环境变量
        let npmPrefix = Shell.run("echo $NPM_CONFIG_PREFIX")
        if !npmPrefix.out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            envConflicts["NPM_CONFIG_PREFIX"] = [npmPrefix.out.trimmingCharacters(in: .whitespacesAndNewlines)]
        }
        
        return ConflictInfo(
            tool: "Node.js",
            managers: managers,
            recommended: "asdf",
            pathConflicts: pathConflicts,
            envConflicts: envConflicts
        )
    }
    
    private func checkPythonConflicts() -> ConflictInfo {
        var managers: [String] = []
        var pathConflicts: [String] = []
        var envConflicts: [String: [String]] = [:]
        
        // 检查pyenv
        let pyenvCheck = Shell.run("command -v pyenv >/dev/null 2>&1; echo $?")
        if pyenvCheck.out.contains("0") {
            managers.append("pyenv")
            pathConflicts.append("$HOME/.pyenv")
        }
        
        // 检查conda
        let condaCheck = Shell.run("command -v conda >/dev/null 2>&1; echo $?")
        if condaCheck.out.contains("0") {
            managers.append("conda")
            let condaPath = Shell.run("conda info --base 2>/dev/null || echo ''")
            if !condaPath.out.isEmpty {
                pathConflicts.append(condaPath.out.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        
        // 检查pipenv
        let pipenvCheck = Shell.run("command -v pipenv >/dev/null 2>&1; echo $?")
        if pipenvCheck.out.contains("0") {
            managers.append("pipenv")
        }
        
        // 检查poetry
        let poetryCheck = Shell.run("command -v poetry >/dev/null 2>&1; echo $?")
        if poetryCheck.out.contains("0") {
            managers.append("poetry")
        }
        
        // 检查asdf python
        let asdfPythonCheck = Shell.run("asdf plugin list | grep -q python && echo 'found' || echo 'not found'")
        if asdfPythonCheck.out.contains("found") {
            managers.append("asdf")
        }
        
        // 检查brew安装的python
        let brewPythonCheck = Shell.run("brew list --formula | grep -q '^python@' && echo 'found' || echo 'not found'")
        if brewPythonCheck.out.contains("found") {
            managers.append("homebrew")
            pathConflicts.append("/opt/homebrew/bin/python3")
        }
        
        // 检查虚拟环境变量
        let virtualEnv = Shell.run("echo $VIRTUAL_ENV")
        if !virtualEnv.out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            envConflicts["VIRTUAL_ENV"] = [virtualEnv.out.trimmingCharacters(in: .whitespacesAndNewlines)]
        }
        
        return ConflictInfo(
            tool: "Python",
            managers: managers,
            recommended: "asdf",
            pathConflicts: pathConflicts,
            envConflicts: envConflicts
        )
    }
    
    private func checkRubyConflicts() -> ConflictInfo {
        var managers: [String] = []
        var pathConflicts: [String] = []
        var envConflicts: [String: [String]] = [:]
        
        // 检查rbenv
        let rbenvCheck = Shell.run("command -v rbenv >/dev/null 2>&1; echo $?")
        if rbenvCheck.out.contains("0") {
            managers.append("rbenv")
            pathConflicts.append("$HOME/.rbenv")
        }
        
        // 检查rvm
        let rvmCheck = Shell.run("command -v rvm >/dev/null 2>&1; echo $?")
        if rvmCheck.out.contains("0") {
            managers.append("rvm")
            pathConflicts.append("$HOME/.rvm")
        }
        
        // 检查chruby
        let chrubyCheck = Shell.run("command -v chruby >/dev/null 2>&1; echo $?")
        if chrubyCheck.out.contains("0") {
            managers.append("chruby")
        }
        
        // 检查asdf ruby
        let asdfRubyCheck = Shell.run("asdf plugin list | grep -q ruby && echo 'found' || echo 'not found'")
        if asdfRubyCheck.out.contains("found") {
            managers.append("asdf")
        }
        
        // 检查brew安装的ruby
        let brewRubyCheck = Shell.run("brew list --formula | grep -q '^ruby$' && echo 'found' || echo 'not found'")
        if brewRubyCheck.out.contains("found") {
            managers.append("homebrew")
            pathConflicts.append("/opt/homebrew/bin/ruby")
        }
        
        return ConflictInfo(
            tool: "Ruby",
            managers: managers,
            recommended: "asdf",
            pathConflicts: pathConflicts,
            envConflicts: envConflicts
        )
    }
    
    private func checkJavaConflicts() -> ConflictInfo {
        var managers: [String] = []
        var pathConflicts: [String] = []
        var envConflicts: [String: [String]] = [:]
        
        // 检查jabba
        let jabbaCheck = Shell.run("command -v jabba >/dev/null 2>&1; echo $?")
        if jabbaCheck.out.contains("0") {
            managers.append("jabba")
            pathConflicts.append("$HOME/.jabba")
        }
        
        // 检查jenv
        let jenvCheck = Shell.run("command -v jenv >/dev/null 2>&1; echo $?")
        if jenvCheck.out.contains("0") {
            managers.append("jenv")
            pathConflicts.append("$HOME/.jenv")
        }
        
        // 检查asdf java
        let asdfJavaCheck = Shell.run("asdf plugin list | grep -q java && echo 'found' || echo 'not found'")
        if asdfJavaCheck.out.contains("found") {
            managers.append("asdf")
        }
        
        // 检查brew安装的java
        let brewJavaCheck = Shell.run("brew list --cask | grep -q 'java' && echo 'found' || echo 'not found'")
        if brewJavaCheck.out.contains("found") {
            managers.append("homebrew")
        }
        
        // 检查系统Java
        let systemJavaCheck = Shell.run("ls /Library/Java/JavaVirtualMachines/ 2>/dev/null | head -5")
        if !systemJavaCheck.out.isEmpty {
            managers.append("system")
            pathConflicts.append("/Library/Java/JavaVirtualMachines/")
        }
        
        // 检查JAVA_HOME
        let javaHome = Shell.run("echo $JAVA_HOME")
        if !javaHome.out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            envConflicts["JAVA_HOME"] = [javaHome.out.trimmingCharacters(in: .whitespacesAndNewlines)]
        }
        
        return ConflictInfo(
            tool: "Java",
            managers: managers,
            recommended: "asdf",
            pathConflicts: pathConflicts,
            envConflicts: envConflicts
        )
    }
    
    /// 获取工具详细信息（版本、路径、管理器等）
    func getToolDetailedInfo(_ tool: String) -> [String: Any] {
        var info: [String: Any] = [:]
        
        switch tool.lowercased() {
        case "node", "nodejs":
            let version = Shell.run("node --version 2>/dev/null || echo 'Not installed'")
            let path = Shell.run("which node 2>/dev/null || echo 'Not found'")
            let npmVersion = Shell.run("npm --version 2>/dev/null || echo 'Not installed'")
            let asdfVersions = Shell.run("asdf list nodejs 2>/dev/null || echo 'No asdf versions'")
            
            info["current_version"] = version.out.trimmingCharacters(in: .whitespacesAndNewlines)
            info["binary_path"] = path.out.trimmingCharacters(in: .whitespacesAndNewlines)
            info["npm_version"] = npmVersion.out.trimmingCharacters(in: .whitespacesAndNewlines)
            info["asdf_versions"] = asdfVersions.out
            
        case "python":
            let version = Shell.run("python3 --version 2>/dev/null || echo 'Not installed'")
            let path = Shell.run("which python3 2>/dev/null || echo 'Not found'")
            let pipVersion = Shell.run("pip3 --version 2>/dev/null || echo 'Not installed'")
            let asdfVersions = Shell.run("asdf list python 2>/dev/null || echo 'No asdf versions'")
            
            info["current_version"] = version.out.trimmingCharacters(in: .whitespacesAndNewlines)
            info["binary_path"] = path.out.trimmingCharacters(in: .whitespacesAndNewlines)
            info["pip_version"] = pipVersion.out.trimmingCharacters(in: .whitespacesAndNewlines)
            info["asdf_versions"] = asdfVersions.out
            
        case "ruby":
            let version = Shell.run("ruby --version 2>/dev/null || echo 'Not installed'")
            let path = Shell.run("which ruby 2>/dev/null || echo 'Not found'")
            let gemVersion = Shell.run("gem --version 2>/dev/null || echo 'Not installed'")
            let asdfVersions = Shell.run("asdf list ruby 2>/dev/null || echo 'No asdf versions'")
            
            info["current_version"] = version.out.trimmingCharacters(in: .whitespacesAndNewlines)
            info["binary_path"] = path.out.trimmingCharacters(in: .whitespacesAndNewlines)
            info["gem_version"] = gemVersion.out.trimmingCharacters(in: .whitespacesAndNewlines)
            info["asdf_versions"] = asdfVersions.out
            
        case "java":
            let version = Shell.run("java -version 2>&1 | head -1 || echo 'Not installed'")
            let path = Shell.run("which java 2>/dev/null || echo 'Not found'")
            let javaHome = Shell.run("echo $JAVA_HOME")
            let asdfVersions = Shell.run("asdf list java 2>/dev/null || echo 'No asdf versions'")
            
            info["current_version"] = version.out.trimmingCharacters(in: .whitespacesAndNewlines)
            info["binary_path"] = path.out.trimmingCharacters(in: .whitespacesAndNewlines)
            info["java_home"] = javaHome.out.trimmingCharacters(in: .whitespacesAndNewlines)
            info["asdf_versions"] = asdfVersions.out
            
        default:
            info["error"] = "Unsupported tool: \(tool)"
        }
        
        return info
    }
}
