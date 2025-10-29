
import Foundation
import AppKit

struct EnvironmentProfile: Codable, Identifiable, Hashable {
    var id: String { name }
    var name: String
    var versions: [String:String] // plugin -> version
}

struct ProfileGroup: Codable, Identifiable, Hashable {
    var id: String { name }
    var name: String
    var profileNames: [String]
}

struct ProfilesStore {
    static let dir: URL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".mac-bootstrap")
    static let profilesPath: URL = dir.appendingPathComponent("profiles.json")
    static let groupsPath: URL = dir.appendingPathComponent("groups.json")
    static let syncFolderPath: URL = dir.appendingPathComponent("sync_folder.txt")

    // Built-ins
    static func builtinProfiles() -> [EnvironmentProfile] {
        return [
            .init(name: "Android Dev", versions: [
                "java": "latest:temurin-17",
                "gradle": "latest",
                "maven": "latest",
                "nodejs": "latest:lts",
                "yarn": "latest",
                "pnpm": "latest",
                "python": "latest"
            ]),
            .init(name: "Go Dev", versions: [
                "golang": "latest",
                "nodejs": "latest:lts",
                "yarn": "latest"
            ]),
            .init(name: "Fullstack Node", versions: [
                "nodejs": "latest:lts",
                "pnpm": "latest",
                "yarn": "latest",
                "python": "latest",
                "java": "latest:temurin-21",
                "maven": "latest",
                "gradle": "latest"
            ]),
            .init(name: "Signer Node", versions: [
                "nodejs": "latest:lts",
                "pnpm": "latest",
                "python": "latest",
                "java": "latest:temurin-17",
                "maven": "latest",
                "gradle": "8.9"
            ])
        ]
    }
    static func builtinGroups() -> [ProfileGroup] {
        return [
            .init(name: "Android Team", profileNames: ["Android Dev"]),
            .init(name: "Go Team", profileNames: ["Go Dev"]),
            .init(name: "Fullstack Team", profileNames: ["Fullstack Node"]),
            .init(name: "Signer/矿工节点", profileNames: ["Signer Node"])
        ]
    }

    // Load/Save
    static func ensureDir() {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    static func loadProfiles() -> [EnvironmentProfile] {
        ensureDir()
        if let data = try? Data(contentsOf: profilesPath),
           let arr = try? JSONDecoder().decode([EnvironmentProfile].self, from: data) {
            return arr
        }
        return builtinProfiles()
    }
    static func saveProfiles(_ profiles: [EnvironmentProfile]) {
        ensureDir()
        if let data = try? JSONEncoder().encode(profiles) {
            try? data.write(to: profilesPath)
        }
    }
    static func loadGroups() -> [ProfileGroup] {
        ensureDir()
        if let data = try? Data(contentsOf: groupsPath),
           let arr = try? JSONDecoder().decode([ProfileGroup].self, from: data) {
            return arr
        }
        return builtinGroups()
    }
    static func saveGroups(_ groups: [ProfileGroup]) {
        ensureDir()
        if let data = try? JSONEncoder().encode(groups) {
            try? data.write(to: groupsPath)
        }
    }

    // Import/Export
    static func importProfilesViaPanel(completion: @escaping ([EnvironmentProfile])->Void) {
        let p = NSOpenPanel()
        p.canChooseFiles = true; p.canChooseDirectories = false; p.allowsMultipleSelection = false
        p.allowedContentTypes = [.json]
        p.begin { resp in
            guard resp == .OK, let url = p.url, let data = try? Data(contentsOf: url),
                  let arr = try? JSONDecoder().decode([EnvironmentProfile].self, from: data) else { completion([]); return }
            completion(arr)
        }
    }
    static func exportProfilesViaPanel(_ profiles: [EnvironmentProfile]) {
        let s = NSSavePanel()
        s.nameFieldStringValue = "profiles.json"
        s.allowedContentTypes = [.json]
        s.begin { resp in
            guard resp == .OK, let url = s.url else { return }
            if let data = try? JSONEncoder().encode(profiles) { try? data.write(to: url) }
        }
    }
    static func importGroupsViaPanel(completion: @escaping ([ProfileGroup])->Void) {
        let p = NSOpenPanel()
        p.canChooseFiles = true; p.canChooseDirectories = false; p.allowsMultipleSelection = false
        p.allowedContentTypes = [.json]
        p.begin { resp in
            guard resp == .OK, let url = p.url, let data = try? Data(contentsOf: url),
                  let arr = try? JSONDecoder().decode([ProfileGroup].self, from: data) else { completion([]); return }
            completion(arr)
        }
    }
    static func exportGroupsViaPanel(_ groups: [ProfileGroup]) {
        let s = NSSavePanel()
        s.nameFieldStringValue = "groups.json"
        s.allowedContentTypes = [.json]
        s.begin { resp in
            guard resp == .OK, let url = s.url else { return }
            if let data = try? JSONEncoder().encode(groups) { try? data.write(to: url) }
        }
    }

    // Sync folder
    static func setSyncFolder(_ url: URL?) {
        ensureDir()
        if let u = url { try? u.path.data(using: .utf8)?.write(to: syncFolderPath) }
    }
    static func getSyncFolder() -> URL? {
        if let data = try? Data(contentsOf: syncFolderPath), let s = String(data: data, encoding: .utf8) {
            return URL(fileURLWithPath: s)
        }
        return nil
    }
    static func chooseSyncFolder(completion: @escaping (URL?)->Void) {
        let p = NSOpenPanel()
        p.canChooseFiles = false; p.canChooseDirectories = true; p.allowsMultipleSelection = false
        p.begin { resp in
            if resp == .OK { completion(p.url) } else { completion(nil) }
        }
    }

    // Merge helpers
    static func mergeProfiles(base: [EnvironmentProfile], incoming: [EnvironmentProfile]) -> [EnvironmentProfile] {
        var dict = Dictionary(uniqueKeysWithValues: base.map{($0.name,$0)})
        for p in incoming { dict[p.name] = p } // replace by name
        return Array(dict.values).sorted{ $0.name < $1.name }
    }
    static func mergeGroups(base: [ProfileGroup], incoming: [ProfileGroup]) -> [ProfileGroup] {
        var dict = Dictionary(uniqueKeysWithValues: base.map{($0.name,$0)})
        for g in incoming { dict[g.name] = g }
        return Array(dict.values).sorted{ $0.name < $1.name }
    }

    // Pull/Push
    static func pullFromSyncFolder() -> (Int, Int) {
        guard let folder = getSyncFolder() else { return (0,0) }
        let pFile = folder.appendingPathComponent("profiles.json")
        let gFile = folder.appendingPathComponent("groups.json")
        var prof = loadProfiles()
        var grp = loadGroups()
        var pc = 0, gc = 0
        if let pdata = try? Data(contentsOf: pFile),
           let parr = try? JSONDecoder().decode([EnvironmentProfile].self, from: pdata) {
            prof = mergeProfiles(base: prof, incoming: parr); saveProfiles(prof); pc = parr.count
        }
        if let gdata = try? Data(contentsOf: gFile),
           let garr = try? JSONDecoder().decode([ProfileGroup].self, from: gdata) {
            grp = mergeGroups(base: grp, incoming: garr); saveGroups(grp); gc = garr.count
        }
        return (pc,gc)
    }
    static func pushToSyncFolder() -> Bool {
        guard let folder = getSyncFolder() else { return false }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let prof = loadProfiles(); let grp = loadGroups()
        if let pdata = try? JSONEncoder().encode(prof) { try? pdata.write(to: folder.appendingPathComponent("profiles.json")) }
        if let gdata = try? JSONEncoder().encode(grp) { try? gdata.write(to: folder.appendingPathComponent("groups.json")) }
        return true
    }
}
