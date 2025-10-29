
import Foundation
import AppKit

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
        let cmd = "bash -c \"$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)\""
        let r = Shell.run(cmd)
        return (true, r.out + r.err, tr("If you prefer bash as login shell, change in System Settings ▶ Users & Groups, or keep zsh."))
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
                let a = Shell.run("asdf list \(plugin) || true").out
                let b = Shell.run("asdf current \(plugin) || true").out
                let c = Shell.run("asdf list all \(plugin) | tail -n 50 || true").out
                out = "Installed:\n\(a)\nCurrent:\n\(b)\nAvailable (tail):\n\(c)"
                ok = true
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

    // Apply a profile (versions map)
    func apply(profile: EnvironmentProfile) -> (Bool, String, String?) {
        var logs = "[Profile] \\(profile.name)\\n"
        for (plugin, version) in profile.versions {
            ensureAsdfAndPlugin(plugin)
            let r = Shell.run("asdf install \(plugin) \"\(version)\" && asdf global \(plugin) \"\(version)\" && asdf reshim \(plugin)")
            logs += "[\(plugin)] \(version) -> code=\(r.code)\\n" + r.out + r.err + "\\n"
        }
        return (true, logs, tr("Profile applied. Reopen terminal for shells to pick up PATH changes if needed."))
    }

    // jabba optional
    private func installJabba() -> (Bool, String, String?) {
        let check = Shell.run("brew list --formula --versions | awk '{print $1}' | grep -qx jabba && echo YES || echo NO")
        if check.out.contains("YES") { return (true, tr("Already installed jabba"), nil) }
        let r = Shell.run("brew install jabba")
        return (r.code == 0, r.out + r.err, tr("jabba manages Java separately; prefer asdf-java for unified profiles."))
    }
}

