
import Foundation
struct Report: Codable {
    struct Item: Codable { let name: String; let installed: Bool; let skipped: Bool; let note: String? }
    var items: [Item]
    func save() -> String? {
        do {
            let data = try JSONEncoder().encode(self)
            let dir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".mac-bootstrap/reports")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let path = dir.appendingPathComponent("report_\(Int(Date().timeIntervalSince1970)).json")
            try data.write(to: path); return path.path
        } catch { return nil }
    }
}
