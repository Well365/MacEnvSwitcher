
import Foundation
import AppKit

struct EnvironmentProfile: Codable, Identifiable, Hashable {
    var id: String { name }
    var name: String
    var description: String = ""
    var versions: [String:String] // plugin -> version
    var virtualEnvs: [String:VirtualEnvironment] = [:] // language -> virtual env config
    var environmentVars: [String:String] = [:] // custom environment variables
    var isActive: Bool = false // track if this is the currently active environment
    var createdAt: Date = Date()
    var lastUsed: Date? = nil
}

struct VirtualEnvironment: Codable, Hashable {
    var type: VirtualEnvType
    var name: String
    var path: String? = nil // custom path if needed
    var pythonVersion: String? = nil // for Python virtual envs
    var gemset: String? = nil // for Ruby gemsets
    var nodeVersion: String? = nil // for Node.js environments
}

enum VirtualEnvType: String, Codable, CaseIterable {
    case pythonVenv = "python-venv"
    case pythonConda = "python-conda"
    case rubyGemset = "ruby-gemset"
    case nodeNvm = "node-nvm"
    case rustToolchain = "rust-toolchain"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .pythonVenv: return "Python venv"
        case .pythonConda: return "Python Conda"
        case .rubyGemset: return "Ruby Gemset"
        case .nodeNvm: return "Node.js NVM"
        case .rustToolchain: return "Rust Toolchain"
        case .custom: return "Custom"
        }
    }
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
            .init(
                name: "Maxwell's Default",
                description: "Current system configuration extracted from .zshrc (Java 8, Gradle 7.6.1, Ruby 2.7.6, Python 3.14.0, Node 23.11.0, Go 1.24.2)",
                versions: [
                    "java": "1.8.0",        // Java 8 (1.8.0_361)
                    "gradle": "7.6.1",      // Gradle 7.6.1
                    "ruby": "2.7.6",        // Ruby 2.7.6
                    "python": "3.14.0",     // Python 3.14.0
                    "nodejs": "23.11.0",    // Node 23.11.0
                    "golang": "1.24.2"      // Go 1.24.2
                ],
                virtualEnvs: [:],
                environmentVars: [
                    "JAVA_HOME": "/Library/Java/JavaVirtualMachines/jdk1.8.0_361.jdk/Contents/Home",
                    "GRADLE_HOME": "/opt/shared_env/android/gradle-7.6.1"
                ]
            ),
            .init(
                name: "Maxwell's Java 11",
                description: "Alternative Java 11 configuration with same tools",
                versions: [
                    "java": "11.0.21",      // Java 11 (11.0.21)
                    "gradle": "7.6.1",
                    "ruby": "2.7.6",
                    "python": "3.14.0",
                    "nodejs": "23.11.0",
                    "golang": "1.24.2"
                ],
                virtualEnvs: [:],
                environmentVars: [
                    "JAVA_HOME": "/Library/Java/JavaVirtualMachines/jdk-11.0.21.jdk/Contents/Home",
                    "GRADLE_HOME": "/opt/shared_env/android/gradle-7.6.1"
                ]
            ),
            .init(
                name: "Maxwell's Java 23",
                description: "Latest Java 23 configuration with same tools",
                versions: [
                    "java": "23.0.2",       // Java 23 (from Homebrew)
                    "gradle": "7.6.1",
                    "ruby": "2.7.6",
                    "python": "3.14.0",
                    "nodejs": "23.11.0",
                    "golang": "1.24.2"
                ],
                virtualEnvs: [:],
                environmentVars: [
                    "JAVA_HOME": "/opt/homebrew/Cellar/openjdk/23.0.2/libexec/openjdk.jdk/Contents/Home",
                    "GRADLE_HOME": "/opt/shared_env/android/gradle-7.6.1"
                ]
            ),
            .init(
                name: "iOS Development", 
                description: "Environment for iOS development with latest stable versions",
                versions: [
                    "ruby": "3.2.0",
                    "python": "3.11.0",
                    "nodejs": "18.17.0",
                    "java": "latest:temurin-17"
                ],
                virtualEnvs: [
                    "python": VirtualEnvironment(type: .pythonVenv, name: "ios-dev", pythonVersion: "3.11.0"),
                    "ruby": VirtualEnvironment(type: .rubyGemset, name: "ios-tools", gemset: "ios-dev")
                ]
            ),
            .init(
                name: "Android Development",
                description: "Environment for Android development",
                versions: [
                    "java": "latest:temurin-17",
                    "gradle": "8.4",
                    "maven": "3.9.4",
                    "nodejs": "18.17.0",
                    "python": "3.11.0"
                ],
                virtualEnvs: [
                    "python": VirtualEnvironment(type: .pythonVenv, name: "android-dev", pythonVersion: "3.11.0")
                ]
            ),
            .init(
                name: "Frontend Development",
                description: "Modern frontend development environment",
                versions: [
                    "nodejs": "20.9.0",
                    "yarn": "latest",
                    "pnpm": "latest",
                    "python": "3.11.0"
                ],
                virtualEnvs: [
                    "nodejs": VirtualEnvironment(type: .nodeNvm, name: "frontend", nodeVersion: "20.9.0")
                ]
            ),
            .init(
                name: "Data Science",
                description: "Python data science environment with conda",
                versions: [
                    "python": "3.11.0",
                    "nodejs": "18.17.0"
                ],
                virtualEnvs: [
                    "python": VirtualEnvironment(type: .pythonConda, name: "datascience", pythonVersion: "3.11.0")
                ]
            ),
            .init(
                name: "Legacy Support",
                description: "Environment for legacy projects",
                versions: [
                    "ruby": "2.7.8",
                    "python": "3.8.17",
                    "nodejs": "16.20.2",
                    "java": "latest:temurin-11"
                ],
                virtualEnvs: [
                    "python": VirtualEnvironment(type: .pythonVenv, name: "legacy", pythonVersion: "3.8.17"),
                    "ruby": VirtualEnvironment(type: .rubyGemset, name: "legacy-tools", gemset: "legacy")
                ]
            )
        ]
    }
    static func builtinGroups() -> [ProfileGroup] {
        return [
            .init(name: "Maxwell's Configurations", profileNames: ["Maxwell's Default", "Maxwell's Java 11", "Maxwell's Java 23"]),
            .init(name: "Mobile Development", profileNames: ["iOS Development", "Android Development"]),
            .init(name: "Web Development", profileNames: ["Frontend Development"]),
            .init(name: "Data & Analytics", profileNames: ["Data Science"]),
            .init(name: "Legacy Projects", profileNames: ["Legacy Support"])
        ]
    }

    // Load/Save
    static func ensureDir() {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    static func loadProfiles() -> [EnvironmentProfile] {
        ensureDir()
        var loadedProfiles: [EnvironmentProfile] = []
        var originalCount = 0
        
        if let data = try? Data(contentsOf: profilesPath),
           let arr = try? JSONDecoder().decode([EnvironmentProfile].self, from: data) {
            loadedProfiles = arr
            originalCount = arr.count
        }
        
        // 如果文件存在但没有 Maxwell's 配置，则自动添加
        if !loadedProfiles.isEmpty {
            let builtins = builtinProfiles()
            let maxwellProfiles = builtins.filter { $0.name.hasPrefix("Maxwell's") }
            
            for maxwellProfile in maxwellProfiles {
                if !loadedProfiles.contains(where: { $0.name == maxwellProfile.name }) {
                    loadedProfiles.insert(maxwellProfile, at: 0)
                }
            }
            
            // 如果添加了新配置，自动保存
            if loadedProfiles.count > originalCount {
                saveProfiles(loadedProfiles)
            }
            
            return loadedProfiles
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
        var loadedGroups: [ProfileGroup] = []
        var originalCount = 0
        
        if let data = try? Data(contentsOf: groupsPath),
           let arr = try? JSONDecoder().decode([ProfileGroup].self, from: data) {
            loadedGroups = arr
            originalCount = arr.count
        }
        
        // 如果文件存在但没有 Maxwell's Configurations 组，则自动添加
        if !loadedGroups.isEmpty {
            let builtins = builtinGroups()
            let maxwellGroup = builtins.first { $0.name == "Maxwell's Configurations" }
            
            if let maxwellGroup = maxwellGroup,
               !loadedGroups.contains(where: { $0.name == maxwellGroup.name }) {
                loadedGroups.insert(maxwellGroup, at: 0)
                saveGroups(loadedGroups)
            }
            
            return loadedGroups
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

    // Environment Management
    static func getCurrentActiveProfile() -> EnvironmentProfile? {
        let profiles = loadProfiles()
        return profiles.first { $0.isActive }
    }
    
    static func setActiveProfile(_ profileName: String) {
        var profiles = loadProfiles()
        for i in profiles.indices {
            profiles[i].isActive = (profiles[i].name == profileName)
            if profiles[i].isActive {
                profiles[i].lastUsed = Date()
            }
        }
        saveProfiles(profiles)
    }
    
    static func deactivateAllProfiles() {
        var profiles = loadProfiles()
        for i in profiles.indices {
            profiles[i].isActive = false
        }
        saveProfiles(profiles)
    }
    
    static func addProfile(_ profile: EnvironmentProfile) {
        var profiles = loadProfiles()
        // Remove existing profile with same name
        profiles.removeAll { $0.name == profile.name }
        profiles.append(profile)
        profiles.sort { $0.name < $1.name }
        saveProfiles(profiles)
    }
    
    static func deleteProfile(_ profileName: String) {
        var profiles = loadProfiles()
        profiles.removeAll { $0.name == profileName }
        saveProfiles(profiles)
    }
    
    static func updateProfile(_ profile: EnvironmentProfile) {
        var profiles = loadProfiles()
        if let index = profiles.firstIndex(where: { $0.name == profile.name }) {
            profiles[index] = profile
            saveProfiles(profiles)
        }
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
    
    // Auto-detect current system configuration
    static func detectCurrentConfiguration() -> EnvironmentProfile {
        var versions: [String: String] = [:]
        var envVars: [String: String] = [:]
        
        // Detect Java
        let javaVersion = Shell.run("java -version 2>&1 | head -1")
        if javaVersion.code == 0, !javaVersion.out.isEmpty {
            // Extract version like "1.8.0_361" or "11.0.21" from output
            if let match = javaVersion.out.range(of: #""(\d+\.\d+\.\d+[^"]*)"#, options: .regularExpression) {
                let ver = String(javaVersion.out[match]).replacingOccurrences(of: "\"", with: "")
                versions["java"] = ver
            }
        }
        let javaHome = Shell.run("echo $JAVA_HOME")
        if !javaHome.out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            envVars["JAVA_HOME"] = javaHome.out.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Detect Python
        let pythonVersion = Shell.run("python3 --version 2>&1")
        if pythonVersion.code == 0, let match = pythonVersion.out.range(of: #"\d+\.\d+\.\d+"#, options: .regularExpression) {
            versions["python"] = String(pythonVersion.out[match])
        }
        
        // Detect Ruby
        let rubyVersion = Shell.run("ruby --version")
        if rubyVersion.code == 0, let match = rubyVersion.out.range(of: #"\d+\.\d+\.\d+"#, options: .regularExpression) {
            versions["ruby"] = String(rubyVersion.out[match])
        }
        
        // Detect Node.js
        let nodeVersion = Shell.run("node --version 2>&1")
        if nodeVersion.code == 0, let match = nodeVersion.out.range(of: #"\d+\.\d+\.\d+"#, options: .regularExpression) {
            versions["nodejs"] = String(nodeVersion.out[match])
        }
        
        // Detect Go
        let goVersion = Shell.run("go version 2>&1")
        if goVersion.code == 0, let match = goVersion.out.range(of: #"go\d+\.\d+\.\d+"#, options: .regularExpression) {
            let ver = String(goVersion.out[match]).replacingOccurrences(of: "go", with: "")
            versions["golang"] = ver
        }
        
        // Detect Gradle
        let gradleVersion = Shell.run("gradle --version 2>&1 | grep 'Gradle ' | head -1")
        if gradleVersion.code == 0, let match = gradleVersion.out.range(of: #"\d+\.\d+\.\d+"#, options: .regularExpression) {
            versions["gradle"] = String(gradleVersion.out[match])
        }
        let gradleHome = Shell.run("echo $GRADLE_HOME")
        if !gradleHome.out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            envVars["GRADLE_HOME"] = gradleHome.out.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Detect Maven
        let mavenVersion = Shell.run("mvn --version 2>&1 | head -1")
        if mavenVersion.code == 0, let match = mavenVersion.out.range(of: #"\d+\.\d+\.\d+"#, options: .regularExpression) {
            versions["maven"] = String(mavenVersion.out[match])
        }
        
        // Detect pnpm
        let pnpmVersion = Shell.run("pnpm --version 2>&1")
        if pnpmVersion.code == 0, let match = pnpmVersion.out.range(of: #"\d+\.\d+\.\d+"#, options: .regularExpression) {
            versions["pnpm"] = String(pnpmVersion.out[match])
        }
        
        // Detect yarn
        let yarnVersion = Shell.run("yarn --version 2>&1")
        if yarnVersion.code == 0, let match = yarnVersion.out.range(of: #"\d+\.\d+\.\d+"#, options: .regularExpression) {
            versions["yarn"] = String(yarnVersion.out[match])
        }
        
        // Detect Rust
        let rustVersion = Shell.run("rustc --version 2>&1")
        if rustVersion.code == 0, let match = rustVersion.out.range(of: #"\d+\.\d+\.\d+"#, options: .regularExpression) {
            versions["rust"] = String(rustVersion.out[match])
        }
        
        let timestamp = Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        return EnvironmentProfile(
            name: "Current System (\(formatter.string(from: timestamp)))",
            description: "Auto-detected system configuration at \(formatter.string(from: timestamp))",
            versions: versions,
            virtualEnvs: [:],
            environmentVars: envVars,
            isActive: false,
            createdAt: timestamp,
            lastUsed: nil
        )
    }
}
