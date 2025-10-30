
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
        var logs = "[Profile] \(profile.name)\n"
        
        // First install/switch language versions
        for (plugin, version) in profile.versions {
            ensureAsdfAndPlugin(plugin)
            let r = Shell.run("asdf install \(plugin) \"\(version)\" && asdf global \(plugin) \"\(version)\" && asdf reshim \(plugin)")
            logs += "[\(plugin)] \(version) -> code=\(r.code)\n" + r.out + r.err + "\n"
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
        
        return (true, logs, tr("Environment '\(profile.name)' activated. Reopen terminal for shells to pick up PATH changes if needed."))
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
                let addToProfile = Shell.run("echo '\(activateScript)' >> ~/.zprofile")
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
                let addToProfile = Shell.run("echo '\(activateScript)' >> ~/.zprofile")
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
                let addToProfile = Shell.run("echo '\(gemsetScript)' >> ~/.zprofile")
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
                let addToProfile = Shell.run("echo '\(nodeScript)' >> ~/.zprofile")
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
            let addToProfile = Shell.run("echo '\(exportCmd)' >> ~/.zprofile")
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
            
            DispatchQueue.main.async {
                completion(result.0, result.1, result.2)
            }
        }
    }
    
    // Deactivate current environment
    func deactivateCurrentEnvironment() -> (Bool, String, String?) {
        ProfilesStore.deactivateAllProfiles()
        
        // Reset to system defaults (could be enhanced to save/restore previous state)
        var logs = "[Deactivate Environment]\n"
        
        // Reset asdf to system versions or latest
        let resetAsdf = Shell.run("asdf global nodejs system; asdf global python system; asdf global ruby system; asdf global java system")
        logs += "Reset asdf to system versions: \(resetAsdf.out)\n"
        
        return (true, logs, tr("Environment deactivated. System defaults restored."))
    }

    // jabba optional
    private func installJabba() -> (Bool, String, String?) {
        let check = Shell.run("brew list --formula --versions | awk '{print $1}' | grep -qx jabba && echo YES || echo NO")
        if check.out.contains("YES") { return (true, tr("Already installed jabba"), nil) }
        let r = Shell.run("brew install jabba")
        return (r.code == 0, r.out + r.err, tr("jabba manages Java separately; prefer asdf-java for unified profiles."))
    }
}

