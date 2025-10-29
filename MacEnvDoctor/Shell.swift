
import Foundation
struct Shell {
    @discardableResult
    static func run(_ command: String, timeout: TimeInterval = 0) -> (code: Int32, out: String, err: String) {
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/zsh"); p.arguments = ["-lc", enrich(command)]
        let outP = Pipe(); let errP = Pipe(); p.standardOutput = outP; p.standardError = errP
        do { try p.run() } catch { return (127, "", "Process error: \(error)") }
        if timeout > 0 { DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { if p.isRunning { p.terminate() } } }
        p.waitUntilExit()
        let out = String(data: outP.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let err = String(data: errP.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (p.terminationStatus, out, err)
    }
    private static func enrich(_ cmd: String) -> String {
        return "export PATH=/opt/homebrew/bin:/usr/local/bin:/opt/homebrew/sbin:/usr/local/sbin:$PATH; " +
               "ASDF_SH=$(brew --prefix asdf 2>/dev/null)/libexec/asdf.sh; if [ -f \"$ASDF_SH\" ]; then . \"$ASDF_SH\"; fi; " + cmd
    }
}
