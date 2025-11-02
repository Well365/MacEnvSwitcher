import Foundation

// MARK: - Version Source Types
enum VersionSourceType: String, Codable {
    case asdf          // asdf 安装和管理
    case homebrew      // Homebrew 安装
    case system        // 系统自带
    case customPath    // 自定义路径
    case notInstalled  // 未安装
}

// MARK: - Version Detection Result
struct VersionDetectionResult {
    let version: String?
    let source: VersionSourceType
    let path: String?
    let installPath: String?  // 安装路径（对于自定义路径）
}

// MARK: - Version Switcher Strategy Manager
/// 版本切换策略管理器 - 统一处理不同来源的版本切换
class VersionSwitcherStrategy {
    static let shared = VersionSwitcherStrategy()
    
    private init() {}
    
    /// 检测工具版本来源
    /// - Parameter tool: 工具名称
    /// - Returns: 检测结果
    static func detectVersionSource(tool: String) -> VersionDetectionResult {
        let toolName = getToolName(for: tool)
        
        // 1. 检查 asdf
        let asdfCheck = Shell.run("asdf current \(tool) 2>/dev/null")
        if asdfCheck.code == 0 && !asdfCheck.out.isEmpty {
            let asdfPath = Shell.run("asdf which \(tool) 2>/dev/null")
            if asdfPath.code == 0 && !asdfPath.out.isEmpty {
                let path = asdfPath.out.trimmingCharacters(in: .whitespacesAndNewlines)
                let version = extractVersionFromAsdfOutput(asdfCheck.out, tool: tool)
                return VersionDetectionResult(
                    version: version,
                    source: .asdf,
                    path: path,
                    installPath: nil
                )
            }
        }
        
        // 2. 检查实际路径
        let whichResult = Shell.run("which \(toolName) 2>/dev/null")
        if whichResult.code == 0 && !whichResult.out.isEmpty {
            let executablePath = whichResult.out.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 检查是否是 Homebrew
            if executablePath.contains("/opt/homebrew/") || executablePath.contains("/usr/local/Cellar/") || executablePath.contains("/usr/local/opt/") {
                let version = getVersionFromTool(tool: tool, toolName: toolName)
                return VersionDetectionResult(
                    version: version,
                    source: .homebrew,
                    path: executablePath,
                    installPath: nil
                )
            }
            
            // 检查是否是系统路径
            if executablePath.starts(with: "/usr/bin/") || executablePath.starts(with: "/usr/sbin/") || executablePath.starts(with: "/bin/") || executablePath.starts(with: "/sbin/") {
                let version = getVersionFromTool(tool: tool, toolName: toolName)
                return VersionDetectionResult(
                    version: version,
                    source: .system,
                    path: executablePath,
                    installPath: nil
                )
            }
            
            // 其他路径视为自定义路径
            let version = getVersionFromTool(tool: tool, toolName: toolName)
            return VersionDetectionResult(
                version: version,
                source: .customPath,
                path: executablePath,
                installPath: executablePath
            )
        }
        
        return VersionDetectionResult(
            version: nil,
            source: .notInstalled,
            path: nil,
            installPath: nil
        )
    }
    
    /// 切换工具版本（根据来源自动选择策略）
    /// - Parameters:
    ///   - tool: 工具名称
    ///   - version: 目标版本
    ///   - targetSource: 目标来源类型（可选，如果指定则强制使用该来源）
    /// - Returns: (成功与否, 日志消息)
    static func switchVersion(tool: String, version: String, targetSource: VersionSourceType? = nil) -> (Bool, String) {
        // 检测当前版本来源
        let currentDetection = detectVersionSource(tool: tool)
        
        // 确定目标来源
        let source = targetSource ?? determineBestSource(tool: tool, version: version)
        
        // 根据来源选择切换策略
        switch source {
        case .asdf:
            return switchAsdfVersion(tool: tool, version: version)
        case .homebrew:
            return switchHomebrewVersion(tool: tool, version: version)
        case .system:
            return switchSystemVersion(tool: tool, version: version)
        case .customPath:
            return switchCustomPathVersion(tool: tool, version: version, path: version)
        case .notInstalled:
            return (false, "❌ [\(tool)] 工具未安装，无法切换版本\n")
        }
    }
    
    /// 确定最佳版本来源
    private static func determineBestSource(tool: String, version: String) -> VersionSourceType {
        // 优先检查 asdf 是否已安装该版本
        let asdfCheck = Shell.run("asdf list \(tool) 2>/dev/null | grep -w '\(version)'")
        if asdfCheck.code == 0 && !asdfCheck.out.isEmpty {
            return .asdf
        }
        
        // 检查 Homebrew 是否可用
        let brewCheck = Shell.run("brew list --versions \(tool) 2>/dev/null")
        if brewCheck.code == 0 && brewCheck.out.contains(version) {
            return .homebrew
        }
        
        // 默认使用 asdf（如果插件已安装）
        let pluginCheck = Shell.run("asdf plugin list 2>/dev/null | grep -q '\(tool)' && echo 'installed'")
        if pluginCheck.out.contains("installed") {
            return .asdf
        }
        
        return .system
    }
    
    // MARK: - 切换策略实现
    
    /// asdf 版本切换
    private static func switchAsdfVersion(tool: String, version: String) -> (Bool, String) {
        return AsdfVersionManager.setGlobalVersion(tool: tool, version: version, installIfMissing: true)
    }
    
    /// Homebrew 版本切换
    private static func switchHomebrewVersion(tool: String, version: String) -> (Bool, String) {
        var log = ""
        
        // 检查版本是否已安装
        let brewCheck = Shell.run("brew list --versions \(tool) 2>/dev/null")
        if brewCheck.code == 0 && brewCheck.out.contains(version) {
            // 版本已安装，切换到该版本
            let switchResult = Shell.run("brew switch \(tool) \(version) 2>&1")
            if switchResult.code == 0 {
                log += "✅ [\(tool)] 已切换到 Homebrew 版本 \(version)\n"
                return (true, log)
            } else {
                log += "⚠️ [\(tool)] Homebrew switch 命令失败，尝试链接版本\n"
                // 尝试使用链接方式
                let linkResult = Shell.run("brew unlink \(tool) 2>&1 && brew link \(tool)@\(version) 2>&1")
                if linkResult.code == 0 {
                    log += "✅ [\(tool)] 已链接到 Homebrew 版本 \(version)\n"
                    return (true, log)
                }
            }
        } else {
            // 尝试安装该版本
            log += "⚠️ [\(tool)] Homebrew 版本 \(version) 未安装，尝试安装...\n"
            let installResult = Shell.run("brew install \(tool)@\(version) 2>&1")
            if installResult.code == 0 {
                log += "✅ [\(tool)] 已安装并切换到 Homebrew 版本 \(version)\n"
                return (true, log)
            } else {
                log += "❌ [\(tool)] Homebrew 安装版本 \(version) 失败: \(installResult.err)\n"
            }
        }
        
        return (false, log)
    }
    
    /// 系统版本切换（通常通过环境变量）
    private static func switchSystemVersion(tool: String, version: String) -> (Bool, String) {
        var log = ""
        
        // 系统版本通常通过环境变量或 PATH 管理
        // 这里主要处理 Java、Python 等系统工具
        switch tool {
        case "java":
            // Java 通过 JAVA_HOME 管理
            let javaHomeResult = Shell.run("/usr/libexec/java_home -v \(version) 2>/dev/null")
            if javaHomeResult.code == 0 && !javaHomeResult.out.isEmpty {
                let javaHome = javaHomeResult.out.trimmingCharacters(in: .whitespacesAndNewlines)
                setenv("JAVA_HOME", javaHome, 1)
                log += "✅ [\(tool)] 已切换到系统版本 \(version) (JAVA_HOME=\(javaHome))\n"
                return (true, log)
            } else {
                log += "❌ [\(tool)] 系统版本 \(version) 不存在\n"
                return (false, log)
            }
        default:
            log += "⚠️ [\(tool)] 系统版本切换需要通过 PATH 配置，请手动设置\n"
            return (false, log)
        }
    }
    
    /// 自定义路径版本切换
    private static func switchCustomPathVersion(tool: String, version: String, path: String) -> (Bool, String) {
        var log = ""
        
        // 验证路径是否存在
        let pathCheck = Shell.run("test -f '\(path)' && echo 'exists'")
        if pathCheck.out.contains("exists") {
            // 通过环境变量或 PATH 设置
            let toolName = getToolName(for: tool)
            let binDir = (path as NSString).deletingLastPathComponent
            setenv("\(toolName.uppercased())_HOME", binDir, 1)
            
            // 更新 PATH
            let currentPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
            let newPath = "\(binDir):\(currentPath)"
            setenv("PATH", newPath, 1)
            
            log += "✅ [\(tool)] 已切换到自定义路径版本: \(path)\n"
            return (true, log)
        } else {
            log += "❌ [\(tool)] 自定义路径不存在: \(path)\n"
            return (false, log)
        }
    }
    
    // MARK: - Helper Methods
    
    /// 获取工具名称（asdf 插件名 -> 可执行文件名）
    private static func getToolName(for tool: String) -> String {
        let toolNameMap: [String: String] = [
            "nodejs": "node",
            "golang": "go"
        ]
        return toolNameMap[tool] ?? tool
    }
    
    /// 从 asdf 输出中提取版本号
    private static func extractVersionFromAsdfOutput(_ output: String, tool: String) -> String? {
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains(tool) {
                let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if components.count >= 2 {
                    return components[1]
                }
            }
        }
        return nil
    }
    
    /// 从工具获取版本号
    private static func getVersionFromTool(tool: String, toolName: String) -> String? {
        let versionCommands: [String: String] = [
            "nodejs": "node --version",
            "python": "python3 --version",
            "ruby": "ruby --version",
            "java": "java --version 2>&1 | head -1 || java -version 2>&1 | head -1",
            "golang": "go version",
            "rust": "rustc --version",
            "php": "php --version",
            "gradle": "gradle --version 2>&1 | head -1"
        ]
        
        let command = versionCommands[tool] ?? "\(toolName) --version"
        let result = Shell.run("\(command) 2>&1")
        
        if result.code == 0 && !result.out.isEmpty {
            // 提取版本号
            let output = result.out
            if let match = output.range(of: #"\d+\.\d+\.\d+"#, options: .regularExpression) {
                return String(output[match])
            } else if let match = output.range(of: #"\d+\.\d+"#, options: .regularExpression) {
                return String(output[match])
            }
        }
        
        return nil
    }
}

