import Foundation

/// 语言检测器
/// 统一处理各种编程语言的版本检测逻辑
class LanguageDetector {
    
    /// 检测结果
    struct DetectionResult {
        let version: String?
        let source: VersionSource
        let path: String?
    }
    
    /// 工具名称映射（asdf 插件名 -> 实际可执行文件名）
    private static let toolNameMap: [String: String] = [
        "nodejs": "node",
        "golang": "go"
    ]
    
    /// 版本命令映射
    private static let versionCommands: [String: String] = [
        "nodejs": "node --version",
        "python": "python3 --version",
        "ruby": "ruby --version",
        "java": "java -version 2>&1 | head -1",
        "golang": "go version",
        "rust": "rustc --version",
        "php": "php --version",
        "scala": "scala -version 2>&1",
        "kotlin": "kotlin -version 2>&1",
        "gradle": "gradle --version 2>&1 | head -1",
        "fastlane": "fastlane --version 2>/dev/null | head -1"
    ]
    
    /// 特殊路径检测配置（语言 ID -> 检测路径列表）
    private static let specialPaths: [String: [String]] = [
        "php": [
            "/opt/homebrew/opt/php/bin/php",
            "/usr/local/opt/php/bin/php",
            "/opt/homebrew/bin/php",
            "/usr/local/bin/php",
            "/usr/bin/php"
        ],
        "nodejs": [
            "/opt/homebrew/opt/node/bin/node",
            "/usr/local/opt/node/bin/node",
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node"
        ],
        "python": [
            "/opt/homebrew/opt/python/bin/python3",
            "/usr/local/opt/python/bin/python3",
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3"
        ],
        "ruby": [
            "/opt/homebrew/opt/ruby/bin/ruby",
            "/usr/local/opt/ruby/bin/ruby",
            "/opt/homebrew/bin/ruby",
            "/usr/local/bin/ruby",
            "/usr/bin/ruby"
        ],
        "golang": [
            "/opt/homebrew/opt/go/bin/go",
            "/usr/local/opt/go/bin/go",
            "/opt/homebrew/bin/go",
            "/usr/local/bin/go"
        ],
        "rust": [
            "/opt/homebrew/opt/rust/bin/rustc",
            "/usr/local/opt/rust/bin/rustc",
            "/opt/homebrew/bin/rustc",
            "/usr/local/bin/rustc"
        ],
        "scala": [
            "/opt/homebrew/opt/scala/bin/scala",
            "/usr/local/opt/scala/bin/scala",
            "/opt/homebrew/bin/scala",
            "/usr/local/bin/scala"
        ],
        "kotlin": [
            "/opt/homebrew/opt/kotlin/bin/kotlin",
            "/usr/local/opt/kotlin/bin/kotlin",
            "/opt/homebrew/bin/kotlin",
            "/usr/local/bin/kotlin"
        ],
        "gradle": [
            "/opt/homebrew/opt/gradle/bin/gradle",
            "/usr/local/opt/gradle/bin/gradle",
            "/opt/homebrew/bin/gradle",
            "/usr/local/bin/gradle"
        ],
        "fastlane": [
            "/opt/homebrew/bin/fastlane",
            "/usr/local/bin/fastlane",
            "/opt/homebrew/opt/fastlane/bin/fastlane",
            "/usr/local/opt/fastlane/bin/fastlane"
        ]
    ]
    
    /// 获取工具的实际可执行文件名
    static func getToolName(for languageId: String) -> String {
        return toolNameMap[languageId] ?? languageId
    }
    
    /// 检测当前版本和来源
    /// - Parameters:
    ///   - languageId: 语言 ID（asdf 插件名）
    ///   - asdfPluginInstalled: asdf 插件是否已安装
    ///   - asdfGlobalVersion: asdf 全局版本（从 ~/.tool-versions 读取）
    /// - Returns: 检测结果（版本、来源、路径）
    static func detectCurrentVersionAndSource(
        languageId: String,
        asdfPluginInstalled: Bool,
        asdfGlobalVersion: String?
    ) -> DetectionResult {
        let toolName = getToolName(for: languageId)
        
        // 检查实际使用的版本和路径
        let whichResult = Shell.run("which \(toolName) 2>/dev/null")
        let versionPath = whichResult.code == 0 && !whichResult.out.isEmpty
            ? whichResult.out.trimmingCharacters(in: .whitespacesAndNewlines)
            : nil
        
        // 获取版本号
        var currentVersion: String? = nil
        var versionSource: VersionSource = .notInstalled
        
        // 优先使用 asdfGlobalVersion（从 ~/.tool-versions 读取的）
        // 但只有当确实有 asdf 版本时才使用，否则继续检测系统版本
        if let globalVer = asdfGlobalVersion, asdfPluginInstalled, !globalVer.isEmpty {
            versionSource = .asdf
            currentVersion = globalVer
        } else if let path = versionPath {
            // 检查是否来自 asdf
            if path.contains("/.asdf/installs/") || path.contains("/asdf/installs/") || path.contains("/asdf/shims/") {
                versionSource = .asdf
                // 从 asdf current 命令获取版本
                let currentResult = Shell.run("asdf current \(languageId) 2>/dev/null")
                if currentResult.code == 0 {
                    let output = currentResult.out.trimmingCharacters(in: .whitespacesAndNewlines)
                    let lines = output.components(separatedBy: .newlines)
                    for line in lines {
                        if line.contains(languageId) {
                            let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                            // 版本通常在第二个位置（第一个是工具名）
                            if components.count >= 2 {
                                currentVersion = components[1]
                                break
                            }
                        }
                    }
                    // 如果解析失败，尝试从 asdfGlobalVersion 获取
                    if currentVersion == nil, let globalVer = asdfGlobalVersion {
                        currentVersion = globalVer
                    }
                }
            }
            // 检查是否来自 Homebrew
            else if path.contains("/opt/homebrew/") || path.contains("/usr/local/Cellar/") {
                versionSource = .homebrew
                currentVersion = getVersionFromTool(languageId: languageId, toolName: toolName)
            }
            // 检查是否系统 Java（macOS 特有）
            else if languageId == "java" && (path.contains("/Library/Java/JavaVirtualMachines/") || path.contains("/usr/libexec/java_home")) {
                versionSource = .system
                // 对于 Java，使用更精确的检测方法
                currentVersion = detectSystemJavaVersion()
            }
            // 检查是否系统自带
            else if path.hasPrefix("/usr/bin/") || path.hasPrefix("/usr/local/bin/") {
                versionSource = .system
                currentVersion = getVersionFromTool(languageId: languageId, toolName: toolName)
            }
            // 检查其他版本管理器
            else {
                versionSource = .other
                currentVersion = getVersionFromTool(languageId: languageId, toolName: toolName)
            }
        } else {
            // 即使找不到路径，如果 asdf 有全局配置，也算作已配置（可能 shell 未正确加载）
            // 但只有当配置不为空时才使用
            if asdfPluginInstalled, let globalVer = asdfGlobalVersion, !globalVer.isEmpty {
                versionSource = .asdf
                currentVersion = globalVer
            } else {
                // 尝试检测特殊路径（如 Homebrew 安装但不在 PATH 中的情况）
                currentVersion = detectFromSpecialPaths(languageId: languageId)
                if currentVersion != nil {
                    // 根据路径判断来源
                    if let specialPaths = specialPaths[languageId] {
                        for specialPath in specialPaths {
                            if specialPath.contains("/opt/homebrew/") || specialPath.contains("/usr/local/opt/") {
                                versionSource = .homebrew
                                break
                            } else {
                                versionSource = .system
                            }
                        }
                    }
                }
            }
        }
        
        return DetectionResult(version: currentVersion, source: versionSource, path: versionPath)
    }
    
    /// 检测系统安装的版本（非 asdf）
    /// - Parameter languageId: 语言 ID
    /// - Returns: 版本字符串，如果无法检测返回 nil
    static func detectSystemInstalledVersion(languageId: String) -> String? {
        let toolName = getToolName(for: languageId)
        
        // 优先检查特殊路径（如 Homebrew 安装但不在 PATH 中的情况）
        if let version = detectFromSpecialPaths(languageId: languageId) {
            return version
        }
        
        // 检查可执行文件是否存在（排除 asdf shims）
        let whichResult = Shell.run("which \(toolName) 2>/dev/null")
        guard whichResult.code == 0, !whichResult.out.isEmpty else {
            return nil
        }
        
        let executablePath = whichResult.out.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 如果是 asdf shim，不算系统安装
        if executablePath.contains("/.asdf/shims/") || executablePath.contains("/.asdf/installs/") {
            return nil
        }
        
        // 使用 getVersionFromTool 获取版本
        return getVersionFromTool(languageId: languageId, toolName: toolName)
    }
    
    /// 从特殊路径检测版本（用于检测 Homebrew 等安装但不在 PATH 中的情况）
    /// - Parameter languageId: 语言 ID
    /// - Returns: 版本字符串，如果无法检测返回 nil
    private static func detectFromSpecialPaths(languageId: String) -> String? {
        guard let paths = specialPaths[languageId] else {
            return nil
        }
        
        for checkPath in paths {
            let checkResult = Shell.run("test -f '\(checkPath)' && '\(checkPath)' --version 2>/dev/null | head -1")
            if checkResult.code == 0, !checkResult.out.isEmpty {
                // 提取版本号
                let output = checkResult.out
                if let match = output.range(of: #"\d+\.\d+\.\d+"#, options: .regularExpression) {
                    return String(output[match])
                } else if let match = output.range(of: #"\d+\.\d+"#, options: .regularExpression) {
                    return String(output[match])
                }
            }
        }
        
        return nil
    }
    
    /// 从工具本身获取版本号
    /// - Parameters:
    ///   - languageId: 语言 ID
    ///   - toolName: 工具名称
    /// - Returns: 版本字符串，如果无法获取返回 nil
    static func getVersionFromTool(languageId: String, toolName: String) -> String? {
        guard let command = versionCommands[languageId] ?? versionCommands[toolName] else {
            return nil
        }
        
        let result = Shell.run(command)
        if result.code == 0, !result.out.isEmpty {
            // 提取版本号（通常是第一个数字版本号）
            let output = result.out
            
            // 对于 Java，特殊处理
            if languageId == "java" {
                // Java 输出格式: openjdk version "11.0.21" 或 java version "1.8.0_361"
                if let match = output.range(of: #""(\d+\.\d+\.\d+[^"]*)"#, options: .regularExpression) {
                    return String(output[match]).replacingOccurrences(of: "\"", with: "")
                } else if let match = output.range(of: #"\d+\.\d+\.\d+"#, options: .regularExpression) {
                    return String(output[match])
                }
            } else if languageId == "fastlane" {
                // Fastlane 输出格式: fastlane 2.228.0 或 fastlane 2.228.0 is available
                if let match = output.range(of: #"fastlane (\d+\.\d+\.\d+)"#, options: .regularExpression) {
                    let fullMatch = String(output[match])
                    return fullMatch.replacingOccurrences(of: "fastlane ", with: "")
                } else if let match = output.range(of: #"\d+\.\d+\.\d+"#, options: .regularExpression) {
                    return String(output[match])
                }
            } else {
                // 其他语言的通用处理
                if let match = output.range(of: #"\d+\.\d+\.\d+"#, options: .regularExpression) {
                    return String(output[match])
                } else if let match = output.range(of: #"\d+\.\d+"#, options: .regularExpression) {
                    return String(output[match])
                }
            }
        }
        return nil
    }
    
    /// 检测当前系统 Java 版本（更精确的方法）
    /// - Returns: 版本字符串，如果无法检测返回 nil
    private static func detectSystemJavaVersion() -> String? {
        // 方法1: 使用 java_home 获取当前版本
        let javaHomeResult = Shell.run("/usr/libexec/java_home -V 2>&1 | head -3")
        if javaHomeResult.code == 0 {
            let output = javaHomeResult.out
            // 第一行通常是当前版本，格式如: "Matching Java Virtual Machines (3):" 或版本信息
            let lines = output.components(separatedBy: .newlines)
            for line in lines {
                // 查找版本号
                if let match = line.range(of: #"\d+\.\d+\.\d+"#, options: .regularExpression) {
                    return String(line[match])
                } else if let match = line.range(of: #"(\d+\.\d+)"#, options: .regularExpression) {
                    return String(line[match])
                }
            }
        }
        
        // 方法2: 使用 java -version
        let javaVersionResult = Shell.run("java -version 2>&1 | head -1")
        if javaVersionResult.code == 0 {
            let output = javaVersionResult.out
            if let match = output.range(of: #""(\d+\.\d+\.\d+[^"]*)"#, options: .regularExpression) {
                return String(output[match]).replacingOccurrences(of: "\"", with: "")
            } else if let match = output.range(of: #"\d+\.\d+\.\d+"#, options: .regularExpression) {
                return String(output[match])
            }
        }
        
        return nil
    }
}

