
import Foundation
import AppKit
import Darwin

// MARK: - Enhanced Profile Structures

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
    
    // Enhanced metadata
    var tags: [String] = [] // 标签，如 ["mobile", "backend", "data-science"]
    var projectType: String = "general" // 项目类型
    var teamInfo: TeamInfo? = nil // 团队信息
    var dependencies: [String] = [] // 依赖的其他profile
    var conflicts: [String] = [] // 与之冲突的profile
    var priority: Int = 0 // 优先级（数字越大优先级越高）
}

struct TeamInfo: Codable, Hashable {
    var teamName: String
    var maintainer: String
    var contact: String? = nil
    var lastUpdated: Date = Date()
    var requiredBy: [String] = [] // 需要此环境的项目列表
    var sharedRepository: String? = nil // 共享仓库地址
}

struct VirtualEnvironment: Codable, Hashable {
    var type: VirtualEnvType
    var name: String
    var path: String? = nil // custom path if needed
    var pythonVersion: String? = nil // for Python virtual envs
    var gemset: String? = nil // for Ruby gemsets
    var nodeVersion: String? = nil // for Node.js environments
    var requirements: [String] = [] // 依赖包列表
    var postInstallScript: String? = nil // 安装后脚本
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
    var description: String = ""
    var isTeamShared: Bool = false
    var accessLevel: AccessLevel = .publicAccess
}

enum AccessLevel: String, Codable, CaseIterable {
    case publicAccess = "public"
    case team = "team"
    case privateAccess = "private"
    
    var displayName: String {
        switch self {
        case .publicAccess: return "公开"
        case .team: return "团队"
        case .privateAccess: return "私有"
        }
    }
}

// MARK: - Environment Matrix Structure

struct EnvironmentMatrix: Codable {
    var name: String
    var description: String = ""
    var environments: [MatrixEnvironment]
    var defaultEnvironment: String? = nil
    var createdAt: Date = Date()
    var version: String = "1.0"
}

struct MatrixEnvironment: Codable, Identifiable {
    var id: String { name }
    var name: String
    var baseProfile: String? = nil // 基础profile名称
    var overrides: EnvironmentProfile // 覆盖配置
    var conditions: [String] = [] // 激活条件，如 ["macOS", ">=12.0"]
    var hooks: EnvironmentHooks? = nil
}

struct EnvironmentHooks: Codable {
    var preActivate: String? = nil // 激活前执行的脚本
    var postActivate: String? = nil // 激活后执行的脚本  
    var preDeactivate: String? = nil // 停用前执行的脚本
    var postDeactivate: String? = nil // 停用后执行的脚本
}

struct ProfilesStore {
    static let dir: URL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".mac-bootstrap")
    static let profilesPath: URL = dir.appendingPathComponent("profiles.json")
    static let groupsPath: URL = dir.appendingPathComponent("groups.json")
    static let syncFolderPath: URL = dir.appendingPathComponent("sync_folder.txt")
    static let matrixPath: URL = dir.appendingPathComponent("environment_matrix.json")
    static let yamlProfilesPath: URL = dir.appendingPathComponent("profiles.yaml")
    static let configPath: URL = dir.appendingPathComponent("config.json")

    // MARK: - YAML Support
    
    /// 导出profile到YAML格式
    static func exportProfilesToYAML(_ profiles: [EnvironmentProfile]) -> String {
        var yaml = """
        # MacEnvSwitcher Environment Profiles
        # Generated on: \(Date())
        # Format Version: 2.0
        
        profiles:
        """
        
        for profile in profiles {
            yaml += """
            
              - name: "\(profile.name)"
                description: "\(profile.description)"
                project_type: "\(profile.projectType)"
                priority: \(profile.priority)
                tags: [\(profile.tags.map { "\"\($0)\"" }.joined(separator: ", "))]
                
                versions:
            """
            
            for (tool, version) in profile.versions.sorted(by: { $0.key < $1.key }) {
                yaml += """
                
                \(tool): "\(version)"
                """
            }
            
            if !profile.environmentVars.isEmpty {
                yaml += "\n\nenvironment_vars:\n"
                for (key, value) in profile.environmentVars.sorted(by: { $0.key < $1.key }) {
                    yaml += "  \(key): \"\(value)\"\n"
                }
            }
            
            if !profile.virtualEnvs.isEmpty {
                yaml += "\n\nvirtual_environments:\n"
                for (lang, venv) in profile.virtualEnvs {
                    yaml += "  \(lang):\n"
                    yaml += "    type: \"\(venv.type.rawValue)\"\n"
                    yaml += "    name: \"\(venv.name)\"\n"
                    
                    if let pythonVersion = venv.pythonVersion {
                        yaml += "    python_version: \"\(pythonVersion)\"\n"
                    }
                    if let gemset = venv.gemset {
                        yaml += "    gemset: \"\(gemset)\"\n"
                    }
                    if !venv.requirements.isEmpty {
                        yaml += "    requirements: [\(venv.requirements.map { "\"\($0)\"" }.joined(separator: ", "))]\n"
                    }
                }
            }
            
            if let teamInfo = profile.teamInfo {
                yaml += "\n\nteam_info:\n"
                yaml += "  team_name: \"\(teamInfo.teamName)\"\n"
                yaml += "  maintainer: \"\(teamInfo.maintainer)\"\n"
                
                if let contact = teamInfo.contact {
                    yaml += "  contact: \"\(contact)\"\n"
                }
                if let repo = teamInfo.sharedRepository {
                    yaml += "  shared_repository: \"\(repo)\"\n"
                }
                if !teamInfo.requiredBy.isEmpty {
                    yaml += "  required_by: [\(teamInfo.requiredBy.map { "\"\($0)\"" }.joined(separator: ", "))]\n"
                }
            }
        }
        
        return yaml
    }
    
    /// 从YAML导入profiles（简化实现，实际项目中建议使用Yams等库）
    static func importProfilesFromYAML(_ yamlContent: String) -> [EnvironmentProfile] {
        // 这里是简化的YAML解析实现
        // 在实际项目中，建议使用专门的YAML解析库如Yams
        print("YAML import feature requires external YAML parsing library")
        return []
    }
    
    // MARK: - Environment Matrix Management
    
    /// 保存环境矩阵
    static func saveEnvironmentMatrix(_ matrix: EnvironmentMatrix) {
        ensureDir()
        if let data = try? JSONEncoder().encode(matrix) {
            try? data.write(to: matrixPath)
        }
    }
    
    /// 加载环境矩阵
    static func loadEnvironmentMatrix() -> EnvironmentMatrix? {
        guard let data = try? Data(contentsOf: matrixPath),
              let matrix = try? JSONDecoder().decode(EnvironmentMatrix.self, from: data) else {
            return nil
        }
        return matrix
    }
    
    /// 创建默认环境矩阵
    static func createDefaultEnvironmentMatrix() -> EnvironmentMatrix {
        let profiles = loadProfiles()
        let environments = profiles.map { profile in
            MatrixEnvironment(
                name: profile.name,
                baseProfile: profile.name,
                overrides: EnvironmentProfile(name: "", description: "", versions: [:]),
                conditions: determineConditions(for: profile)
            )
        }
        
        return EnvironmentMatrix(
            name: "Default Environment Matrix",
            description: "Auto-generated environment matrix based on existing profiles",
            environments: environments,
            defaultEnvironment: profiles.first?.name
        )
    }
    
    /// 根据profile确定激活条件
    private static func determineConditions(for profile: EnvironmentProfile) -> [String] {
        var conditions: [String] = []
        
        // 根据项目类型添加条件
        switch profile.projectType {
        case "ios", "swift":
            conditions.append("platform:macOS")
            conditions.append("xcode:available")
        case "android":
            conditions.append("java:>=11")
        case "web", "frontend":
            conditions.append("nodejs:>=16")
        case "data-science":
            conditions.append("python:>=3.8")
            conditions.append("memory:>=8GB")
        default:
            break
        }
        
        // 根据标签添加条件
        if profile.tags.contains("mobile") {
            conditions.append("development:mobile")
        }
        if profile.tags.contains("backend") {
            conditions.append("development:backend")
        }
        
        return conditions
    }
    
    // MARK: - Enhanced Team Collaboration
    
    /// 创建团队共享配置
    static func createTeamConfiguration(teamName: String, profiles: [EnvironmentProfile]) -> Bool {
        let teamConfig = [
            "team_name": teamName,
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "profiles": profiles.map { $0.name },
            "version": "1.0"
        ] as [String : Any]
        
        let teamConfigPath = dir.appendingPathComponent("team_\(teamName.lowercased()).json")
        
        do {
            let data = try JSONSerialization.data(withJSONObject: teamConfig, options: .prettyPrinted)
            try data.write(to: teamConfigPath)
            return true
        } catch {
            print("Failed to create team configuration: \(error)")
            return false
        }
    }
    
    /// 加载团队配置
    static func loadTeamConfiguration(teamName: String) -> [String: Any]? {
        let teamConfigPath = dir.appendingPathComponent("team_\(teamName.lowercased()).json")
        
        guard let data = try? Data(contentsOf: teamConfigPath),
              let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        return config
    }
    
    /// 同步团队profiles
    static func syncTeamProfiles(teamName: String) -> (Int, Int, [String]) {
        guard let teamConfig = loadTeamConfiguration(teamName: teamName),
              let profileNames = teamConfig["profiles"] as? [String] else {
            return (0, 0, ["Team configuration not found"])
        }
        
        var syncedProfiles = 0
        var errors: [String] = []
        let currentProfiles = loadProfiles()
        
        for profileName in profileNames {
            if !currentProfiles.contains(where: { $0.name == profileName }) {
                errors.append("Profile '\(profileName)' not found locally")
            } else {
                syncedProfiles += 1
            }
        }
        
        return (syncedProfiles, profileNames.count, errors)
    }
    
    // MARK: - Smart Profile Recommendations
    
    /// 智能推荐profiles
    static func recommendProfiles(for projectPath: String) -> [EnvironmentProfile] {
        // 简化版实现，检测项目文件并推荐对应的profile
        let allProfiles = loadProfiles()
        let projectURL = URL(fileURLWithPath: projectPath)
        var recommendations: [EnvironmentProfile] = []
        
        // 检测项目类型
        let commonFiles = [
            "package.json": "nodejs",
            "Gemfile": "ruby",
            "requirements.txt": "python",
            "pyproject.toml": "python",
            "go.mod": "golang",
            "pom.xml": "java",
            "build.gradle": "java",
            "Cargo.toml": "rust",
            "Podfile": "ios"
        ]
        
        var detectedLanguages: [String] = []
        for (file, language) in commonFiles {
            let fileURL = projectURL.appendingPathComponent(file)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                detectedLanguages.append(language)
            }
        }
        
        for profile in allProfiles {
            var score = 0
            
            // 检查是否包含检测到的语言
            for language in detectedLanguages {
                if profile.versions.keys.contains(language) || 
                   profile.versions.keys.contains("\(language)_asdf") ||
                   profile.versions.keys.contains("python") && language == "python" ||
                   profile.versions.keys.contains("nodejs") && language == "nodejs" {
                    score += 10
                }
                if profile.tags.contains(language) {
                    score += 5
                }
            }
            
            // 检查项目类型匹配
            if detectedLanguages.contains(profile.projectType) {
                score += 15
            }
            
            // 优先级加分
            score += profile.priority
            
            if score > 0 {
                var recommendedProfile = profile
                recommendedProfile.priority = score // 临时存储推荐分数
                recommendations.append(recommendedProfile)
            }
        }
        
        return recommendations.sorted { $0.priority > $1.priority }.prefix(5).map { $0 }
    }
    
    // MARK: - Profile Validation and Health Check
    
    /// 验证profile的完整性
    static func validateProfile(_ profile: EnvironmentProfile) -> [String] {
        var issues: [String] = []
        
        // 检查必要字段
        if profile.name.isEmpty {
            issues.append("Profile name cannot be empty")
        }
        
        // 检查版本格式
        for (tool, version) in profile.versions {
            if version.isEmpty {
                issues.append("Version for \(tool) cannot be empty")
            }
            
            // 检查版本是否可用
            let checkResult = Shell.run("asdf list all \(tool) 2>/dev/null | grep -q '\(version)' && echo 'found' || echo 'not found'")
            if checkResult.out.contains("not found") && !["latest", "system"].contains(version) {
                issues.append("Version \(version) for \(tool) may not be available")
            }
        }
        
        // 检查环境变量冲突
        for (key, _) in profile.environmentVars {
            if ["PATH", "HOME", "USER"].contains(key) {
                issues.append("Environment variable \(key) should not be overridden")
            }
        }
        
        // 检查依赖关系
        for dependency in profile.dependencies {
            let allProfiles = loadProfiles()
            if !allProfiles.contains(where: { $0.name == dependency }) {
                issues.append("Dependency profile '\(dependency)' not found")
            }
        }
        
        return issues
    }
    
    /// 健康检查所有profiles
    static func healthCheckAllProfiles() -> [String: [String]] {
        let profiles = loadProfiles()
        var results: [String: [String]] = [:]
        
        for profile in profiles {
            let issues = validateProfile(profile)
            if !issues.isEmpty {
                results[profile.name] = issues
            }
        }
        
        return results
    }
    
    // MARK: - Profile Analytics and Usage Tracking
    
    /// 记录profile使用情况
    static func trackProfileUsage(_ profileName: String, action: String) {
        let usageData = [
            "profile": profileName,
            "action": action,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "system": getSystemInfo()
        ] as [String : Any]
        
        let usageLogPath = dir.appendingPathComponent("usage.log")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: usageData)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            
            if FileManager.default.fileExists(atPath: usageLogPath.path) {
                let handle = try FileHandle(forWritingTo: usageLogPath)
                handle.seekToEndOfFile()
                handle.write((jsonString + "\n").data(using: .utf8) ?? Data())
                handle.closeFile()
            } else {
                try (jsonString + "\n").write(to: usageLogPath, atomically: true, encoding: .utf8)
            }
        } catch {
            print("Failed to track usage: \(error)")
        }
    }
    
    /// 获取系统信息用于使用情况追踪
    private static func getSystemInfo() -> [String: String] {
        // 获取机器架构
        let archResult = Shell.run("uname -m")
        let arch = archResult.code == 0 ? archResult.out.trimmingCharacters(in: .whitespacesAndNewlines) : "unknown"
        
        return [
            "os": "macOS",
            "arch": arch,
            "version": ProcessInfo.processInfo.operatingSystemVersionString
        ]
    }
    
    /// 生成使用情况报告
    static func generateUsageReport() -> [String: Any] {
        let usageLogPath = dir.appendingPathComponent("usage.log")
        
        guard let content = try? String(contentsOf: usageLogPath) else {
            return ["error": "No usage data found"]
        }
        
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        var profileUsage: [String: Int] = [:]
        var actionCounts: [String: Int] = [:]
        
        for line in lines {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let profile = json["profile"] as? String,
                  let action = json["action"] as? String else {
                continue
            }
            
            profileUsage[profile, default: 0] += 1
            actionCounts[action, default: 0] += 1
        }
        
        return [
            "total_events": lines.count,
            "profile_usage": profileUsage,
            "action_counts": actionCounts,
            "most_used_profile": profileUsage.max(by: { $0.value < $1.value })?.key ?? "none"
        ]
    }

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
        guard let profileIndex = profiles.firstIndex(where: { $0.name == profileName }) else {
            print("⚠️ Profile '\(profileName)' not found")
            return
        }
        
        let profile = profiles[profileIndex]
        
        // 先取消所有配置的激活状态
        for i in profiles.indices {
            profiles[i].isActive = false
        }
        
        // 激活选中的配置
        profiles[profileIndex].isActive = true
        profiles[profileIndex].lastUsed = Date()
        
        // 保存配置文件状态
        saveProfiles(profiles)
        
        // 立即应用环境配置（全局切换）
        applyEnvironmentConfigurationImmediately(profile: profile)
        
        // 应用系统级配置
        applySystemConfiguration(profile: profile)
    }
    
    // 立即应用环境配置（全局切换）
    private static func applyEnvironmentConfigurationImmediately(profile: EnvironmentProfile) {
        var logs = "🔄 正在切换全局环境到 '\(profile.name)'...\n\n"
        var success = true
        var toolDetails: [String: (from: String?, to: String, fromSource: String?, toSource: String, success: Bool)] = [:]
        
        // 1. 切换全局版本
        for (tool, version) in profile.versions {
            // 检测当前版本来源并切换版本
            let toolResult = switchGlobalTool(tool: tool, version: version)
            logs += toolResult.1
            
            let toolSuccess = toolResult.0
            
            // 检测切换后的版本来源
            let newDetection = VersionSwitcherStrategy.detectVersionSource(tool: tool)
            let toSource = newDetection.source.rawValue
            
            // 记录工具切换详情
            toolDetails[tool] = (
                from: nil, // 不再记录 fromVersion，简化逻辑
                to: version,
                fromSource: nil,
                toSource: toSource,
                success: toolSuccess
            )
            
            if !toolSuccess {
                success = false
            }
        }
        
        // 2. 更新全局 .tool-versions 文件
        updateGlobalToolVersions(profile: profile)
        
        // 3. 更新 shell 配置文件（.zshrc, .bash_profile 等）
        updateShellProfileFiles(profile: profile)
        
        // 4. 刷新 asdf shims
        let reshimResult = Shell.run("asdf reshim")
        if reshimResult.code == 0 {
            logs += "\n✅ 已刷新所有工具的shims\n"
        } else {
            logs += "\n⚠️ 刷新shims时出现警告: \(reshimResult.err)\n"
        }
        
        // 5. 应用环境变量
        applyEnvironmentVariables(profile: profile)
        
        // 6. 记录日志
        SwitchLogManager.shared.logEnvironmentSwitch(
            profileName: profile.name,
            success: success,
            log: logs,
            details: toolDetails
        )
        
        // 7. 发送通知以更新界面
        NotificationCenter.default.post(name: .environmentSwitched, object: profile)
        
        if success {
            print("✅ Environment switched successfully: \(logs)")
        } else {
            print("⚠️ Environment switched with warnings: \(logs)")
        }
    }
    
    // 切换单个工具的全局版本（使用统一的版本切换策略）
    private static func switchGlobalTool(tool: String, version: String) -> (Bool, String) {
        // Java 和 Gradle 特殊处理
        if tool == "java" || tool == "gradle" {
            // 对于 Java，优先使用环境变量
            if tool == "java" {
                // Java 通常通过 JAVA_HOME 环境变量管理
                if let javaHome = ProcessInfo.processInfo.environment["JAVA_HOME"],
                   !javaHome.isEmpty {
                    return (true, "ℹ️ [java] 版本将通过 JAVA_HOME 环境变量配置\n")
                }
                // 尝试通过 asdf 管理
                return VersionSwitcherStrategy.switchVersion(tool: "java", version: version, targetSource: VersionSourceType.asdf)
            }
            
            // 对于 Gradle，使用环境变量
            return (true, "ℹ️ [\(tool)] 版本 \(version) 将通过环境变量配置\n")
        }
        
        // 使用统一的版本切换策略管理器
        return VersionSwitcherStrategy.switchVersion(tool: tool, version: version)
    }
    
    // 更新全局 .tool-versions 文件
    private static func updateGlobalToolVersions(profile: EnvironmentProfile) {
        let homeDir = NSHomeDirectory()
        let toolVersionsPath = homeDir + "/.tool-versions"
        
        var content = "# asdf tool versions\n"
        content += "# Managed by MacEnvSwitcher\n"
        content += "# Profile: \(profile.name)\n"
        content += "# Last updated: \(Date())\n\n"
        
        // 按字母顺序排序工具
        for (plugin, version) in profile.versions.sorted(by: { $0.key < $1.key }) {
            content += "\(plugin) \(version)\n"
        }
        
        do {
            try content.write(toFile: toolVersionsPath, atomically: true, encoding: .utf8)
            print("✅ Updated global .tool-versions file")
        } catch {
            print("⚠️ Failed to update .tool-versions: \(error.localizedDescription)")
        }
    }
    
    // 更新 shell 配置文件
    private static func updateShellProfileFiles(profile: EnvironmentProfile) {
        let shellConfigFiles = ["~/.zshrc", "~/.bash_profile", "~/.bashrc"]
        
        for configFile in shellConfigFiles {
            let expandedPath = NSString(string: configFile).expandingTildeInPath
            
            // 确保文件存在
            if !FileManager.default.fileExists(atPath: expandedPath) {
                // 创建文件（如果不存在）
                try? "# Created by MacEnvSwitcher\n".write(toFile: expandedPath, atomically: true, encoding: .utf8)
            }
            
            guard var content = try? String(contentsOfFile: expandedPath, encoding: .utf8) else {
                continue
            }
            
            let marker = "# MacEnvSwitcher Environment Configuration"
            let endMarker = "# End MacEnvSwitcher Configuration"
            
            // 移除旧的配置段
            if let startRange = content.range(of: marker),
               let endRange = content.range(of: endMarker) {
                let rangeToRemove = startRange.lowerBound..<endRange.upperBound
                content.removeSubrange(rangeToRemove)
                content = content.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            // 添加新的配置段
            var configSection = "\n\n\(marker)\n"
            configSection += "# Profile: \(profile.name)\n"
            configSection += "# Last updated: \(Date())\n\n"
            
            // 添加 asdf 初始化（如果还没有）
            if !content.contains("asdf.sh") {
                configSection += "# Initialize asdf\n"
                configSection += "if command -v asdf >/dev/null 2>&1; then\n"
                configSection += "    ASDF_SH=$(brew --prefix asdf 2>/dev/null)/libexec/asdf.sh\n"
                configSection += "    [ -f \"$ASDF_SH\" ] && source \"$ASDF_SH\"\n"
                configSection += "fi\n\n"
            }
            
            // 确保 asdf shims 在 PATH 最前面（优先级最高）
            // 这必须在任何其他 PATH 设置之前执行
            // 特别重要：移除系统、Homebrew 和其他版本管理器的 Ruby/Node/Python 路径
            configSection += "# Ensure asdf shims have highest priority in PATH\n"
            configSection += "# This removes system/Homebrew/other version manager paths for tools managed by asdf\n"
            configSection += "if command -v asdf >/dev/null 2>&1; then\n"
            configSection += "    ASDF_SHIMS=$(asdf where asdf 2>/dev/null)/shims\n"
            configSection += "    ASDF_BIN=$(asdf where asdf 2>/dev/null)/bin\n"
            configSection += "    if [ -n \"$ASDF_SHIMS\" ] && [ -n \"$ASDF_BIN\" ]; then\n"
            configSection += "        # Filter out conflicting paths for tools managed by asdf\n"
            configSection += "        # Remove: Homebrew Ruby/Node/Python paths, rbenv paths\n"
            configSection += "        # Keep system paths (/usr/bin, /bin, /sbin) but ensure asdf shims come first\n"
            configSection += "        NEW_PATH=$(echo \"$PATH\" | tr ':' '\\n' | \\\n"
            configSection += "            grep -vE '/opt/homebrew/opt/(ruby|node|python)/bin' | \\\n"
            configSection += "            grep -vE '/usr/local/opt/(ruby|node|python)/bin' | \\\n"
            configSection += "            grep -vE '/opt/homebrew/opt/(ruby|node|python)/sbin' | \\\n"
            configSection += "            grep -vE '/usr/local/opt/(ruby|node|python)/sbin' | \\\n"
            configSection += "            grep -vE '/\\.rbenv/shims' | \\\n"
            configSection += "            grep -vE '/\\.rbenv/bin' | \\\n"
            configSection += "            tr '\\n' ':' | sed 's/:$//' | sed 's/^://')\n"
            configSection += "        # Add asdf shims at the very beginning\n"
            configSection += "        export PATH=\"$ASDF_SHIMS:$ASDF_BIN:$NEW_PATH\"\n"
            configSection += "    fi\n"
            configSection += "fi\n\n"
            
            // 添加 asdf 全局版本设置（确保所有工具版本正确）
            if !profile.versions.isEmpty {
                configSection += "# Set asdf global versions (override project .tool-versions)\n"
                for (plugin, version) in profile.versions.sorted(by: { $0.key < $1.key }) {
                    // 跳过 Java 和 Gradle，因为它们通常不是通过 asdf 管理的
                    if plugin != "java" && plugin != "gradle" {
                        configSection += "if command -v asdf >/dev/null 2>&1; then\n"
                        // 在 shell 脚本中检测 asdf 版本并使用正确的命令
                        configSection += "    # Detect asdf version and use correct command\n"
                        configSection += "    ASDF_VERSION=$(asdf version 2>&1 | head -1)\n"
                        configSection += "    if echo \"$ASDF_VERSION\" | grep -qE '0\\.(1[6-9]|[89])'; then\n"
                        configSection += "        # asdf 0.16+ uses 'set -u' for global\n"
                        configSection += "        asdf set -u \(plugin) \"\(version)\" 2>/dev/null || true\n"
                        configSection += "    else\n"
                        configSection += "        # Older asdf versions use 'global'\n"
                        configSection += "        asdf global \(plugin) \"\(version)\" 2>/dev/null || true\n"
                        configSection += "    fi\n"
                        // 强制使用全局版本（覆盖项目目录的 .tool-versions）
                        // 设置环境变量强制版本
                        configSection += "    export ASDF_\(plugin.uppercased())_VERSION=\"\(version)\"\n"
                        // 刷新 shims
                        configSection += "    asdf reshim \(plugin) 2>/dev/null || true\n"
                        configSection += "fi\n"
                    }
                }
                configSection += "\n"
            }
            
            // 添加 Java 特殊处理（优先使用环境变量中指定的 JAVA_HOME）
            if let javaHome = profile.environmentVars["JAVA_HOME"] {
                configSection += "# Java configuration (from profile)\n"
                configSection += "export JAVA_HOME=\"\(javaHome)\"\n"
                configSection += "[ -d \"$JAVA_HOME\" ] && export PATH=\"$JAVA_HOME/bin:$PATH\"\n"
            } else if let javaVersion = profile.versions["java"] {
                // 如果没有指定 JAVA_HOME，尝试通过 asdf 获取
                configSection += "# Java configuration (via asdf)\n"
                configSection += "if command -v asdf >/dev/null 2>&1; then\n"
                configSection += "    JAVA_HOME_ASDF=$(asdf where java \(javaVersion) 2>/dev/null)\n"
                configSection += "    if [ -n \"$JAVA_HOME_ASDF\" ] && [ -d \"$JAVA_HOME_ASDF\" ]; then\n"
                configSection += "        export JAVA_HOME=\"$JAVA_HOME_ASDF\"\n"
                configSection += "        export PATH=\"$JAVA_HOME/bin:$PATH\"\n"
                configSection += "    fi\n"
                configSection += "fi\n"
            }
            
            // 添加 Gradle 特殊处理
            if let gradleHome = profile.environmentVars["GRADLE_HOME"] {
                configSection += "\n# Gradle configuration\n"
                configSection += "export GRADLE_HOME=\"\(gradleHome)\"\n"
                configSection += "[ -d \"$GRADLE_HOME\" ] && export PATH=\"$GRADLE_HOME/bin:$PATH\"\n"
            }
            
            // 添加其他环境变量（排除已经特殊处理的）
            let excludedKeys = ["JAVA_HOME", "GRADLE_HOME"]
            for (key, value) in profile.environmentVars.sorted(by: { $0.key < $1.key }) {
                if !excludedKeys.contains(key) {
                    configSection += "export \(key)=\"\(value)\"\n"
                }
            }
            
            // 刷新 asdf shims 以确保命令可用
            configSection += "\n# Refresh asdf shims\n"
            configSection += "if command -v asdf >/dev/null 2>&1; then\n"
            configSection += "    asdf reshim 2>/dev/null || true\n"
            configSection += "fi\n"
            
            configSection += "\n\(endMarker)\n"
            
            content += configSection
            
            // 写回文件
            do {
                try content.write(toFile: expandedPath, atomically: true, encoding: .utf8)
                print("✅ Updated \(configFile)")
            } catch {
                print("⚠️ Failed to update \(configFile): \(error.localizedDescription)")
            }
        }
    }
    
    // 应用环境变量到当前进程
    private static func applyEnvironmentVariables(profile: EnvironmentProfile) {
        for (key, value) in profile.environmentVars {
            setenv(key, value, 1)
        }
        
        // 设置 asdf 版本环境变量
        for (plugin, version) in profile.versions {
            let envKey = "ASDF_\(plugin.uppercased())_VERSION"
            setenv(envKey, version, 1)
        }
    }
    
    // 应用系统级配置
    private static func applySystemConfiguration(profile: EnvironmentProfile) {
        // 保存当前活跃配置到系统偏好设置
        let defaults = UserDefaults.standard
        defaults.set(profile.name, forKey: "MacEnvSwitcher.ActiveProfile")
        defaults.set(Date(), forKey: "MacEnvSwitcher.LastSwitched")
        
        // 保存版本配置到系统
        for (plugin, version) in profile.versions {
            defaults.set(version, forKey: "MacEnvSwitcher.Version.\(plugin)")
        }
        
        // 保存环境变量配置
        for (key, value) in profile.environmentVars {
            defaults.set(value, forKey: "MacEnvSwitcher.Env.\(key)")
        }
        
        defaults.synchronize()
        
        // 创建或更新系统配置文件
        createSystemConfigFile(profile: profile)
    }
    
    // 创建系统配置文件
    private static func createSystemConfigFile(profile: EnvironmentProfile) {
        let configDir = NSHomeDirectory() + "/.macenvswitcher"
        let configFile = configDir + "/current_environment.sh"
        
        // 创建配置目录
        let createDirResult = Shell.run("mkdir -p '\(configDir)'")
        guard createDirResult.code == 0 else { return }
        
        // 生成配置脚本内容
        var configContent = """
        #!/bin/bash
        # MacEnvSwitcher Current Environment Configuration
        # Generated on: \(Date())
        # Profile: \(profile.name)
        
        # Version settings
        """
        
        for (plugin, version) in profile.versions {
            configContent += """
            
            asdf global \(plugin) "\(version)"
            """
        }
        
        configContent += """
        
        
        # Environment variables
        """
        
        for (key, value) in profile.environmentVars {
            configContent += """
            
            export \(key)="\(value)"
            """
        }
        
        configContent += """
        
        
        # Refresh shims
        asdf reshim
        
        echo "MacEnvSwitcher: Environment '\(profile.name)' loaded"
        """
        
        // 写入配置文件
        do {
            try configContent.write(toFile: configFile, atomically: true, encoding: .utf8)
            // 使文件可执行
            _ = Shell.run("chmod +x '\(configFile)'")
        } catch {
            print("Failed to write system config file: \(error)")
        }
    }
    
    // 恢复系统配置
    static func restoreSystemConfiguration() {
        let configFile = NSHomeDirectory() + "/.macenvswitcher/current_environment.sh"
        let fileManager = FileManager.default
        
        if fileManager.fileExists(atPath: configFile) {
            let loadResult = Shell.run("source '\(configFile)'")
            if loadResult.code == 0 {
                print("✅ System configuration restored")
            } else {
                print("⚠️ Failed to restore system configuration: \(loadResult.err)")
            }
        }
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
        
        // Detect Java - try --version first (newer Java), then fallback to -version
        var javaVersion = Shell.run("java --version 2>&1 | head -1")
        if javaVersion.code != 0 || javaVersion.out.isEmpty {
            javaVersion = Shell.run("java -version 2>&1 | head -1")
        }
        if javaVersion.code == 0, !javaVersion.out.isEmpty {
            // Extract version like "1.8.0_361" or "11.0.21" or "openjdk version \"17.0.17\"" from output
            if let match = javaVersion.out.range(of: #""(\d+\.\d+\.\d+[^"]*)"#, options: .regularExpression) {
                let ver = String(javaVersion.out[match]).replacingOccurrences(of: "\"", with: "")
                versions["java"] = ver
            } else if let match = javaVersion.out.range(of: #"version\s+"(\d+\.\d+\.\d+[^"]*)"#, options: .regularExpression) {
                let ver = String(javaVersion.out[match]).replacingOccurrences(of: "version \"", with: "").replacingOccurrences(of: "\"", with: "")
                versions["java"] = ver
            } else if let match = javaVersion.out.range(of: #"\d+\.\d+\.\d+"#, options: .regularExpression) {
                versions["java"] = String(javaVersion.out[match])
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

// MARK: - Environment Switch Notification
extension Notification.Name {
    static let environmentSwitched = Notification.Name("EnvironmentSwitched")
}
