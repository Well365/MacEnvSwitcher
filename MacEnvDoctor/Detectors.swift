
import Foundation

struct CheckResult { let ok: Bool; let log: String; let tip: String? }

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
}
