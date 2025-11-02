import Foundation

/// .tool-versions 文件管理器
/// 负责 asdf 工具版本文件的读取、写入、修改和删除操作
class ToolVersionsManager {
    
    /// .tool-versions 文件的路径
    static var filePath: String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(homeDir)/.tool-versions"
    }
    
    // MARK: - 读取操作
    
    /// 读取所有语言的版本配置
    /// - Returns: 语言ID到版本的字典，如果文件不存在或读取失败返回空字典
    static func readAllVersions() -> [String: String] {
        let filePath = self.filePath
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: filePath),
              let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            print("📝 [ToolVersionsManager] 文件不存在或无法读取: \(filePath)")
            return [:]
        }
        
        var versions: [String: String] = [:]
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            // 跳过空行和注释
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            
            // 解析格式: languageId version
            let components = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if components.count >= 2 {
                let languageId = components[0]
                let version = components[1]
                versions[languageId] = version
                print("📖 [ToolVersionsManager] 读取到: \(languageId) = \(version)")
            }
        }
        
        return versions
    }
    
    /// 读取指定语言的版本
    /// - Parameter languageId: 语言ID
    /// - Returns: 版本字符串，如果不存在返回 nil
    static func readVersion(for languageId: String) -> String? {
        return readAllVersions()[languageId]
    }
    
    // MARK: - 写入操作
    
    /// 设置指定语言的版本
    /// - Parameters:
    ///   - languageId: 语言ID
    ///   - version: 版本字符串
    /// - Returns: 是否成功
    static func setVersion(for languageId: String, version: String) -> Bool {
        var versions = readAllVersions()
        versions[languageId] = version
        return writeAllVersions(versions)
    }
    
    /// 写入所有版本配置
    /// - Parameter versions: 语言ID到版本的字典
    /// - Returns: 是否成功
    static func writeAllVersions(_ versions: [String: String]) -> Bool {
        let filePath = self.filePath
        let fileManager = FileManager.default
        
        // 如果文件不存在，创建它
        if !fileManager.fileExists(atPath: filePath) {
            fileManager.createFile(atPath: filePath, contents: nil, attributes: nil)
        }
        
        // 构建文件内容
        var content = "# asdf tool versions\n"
        content += "# Managed by MacEnvSwitcher\n"
        content += "# Last updated: \(Date())\n\n"
        
        // 按语言ID排序写入
        for (languageId, version) in versions.sorted(by: { $0.key < $1.key }) {
            content += "\(languageId) \(version)\n"
        }
        
        // 写入文件
        do {
            try content.write(toFile: filePath, atomically: true, encoding: .utf8)
            print("✅ [ToolVersionsManager] 已写入 \(versions.count) 个语言版本配置")
            return true
        } catch {
            print("❌ [ToolVersionsManager] 写入文件失败: \(error)")
            return false
        }
    }
    
    // MARK: - 删除操作
    
    /// 删除指定语言的配置
    /// - Parameter languageId: 语言ID
    /// - Returns: 是否成功（如果语言不存在也返回 true）
    static func removeVersion(for languageId: String) -> Bool {
        var versions = readAllVersions()
        
        guard versions.removeValue(forKey: languageId) != nil else {
            print("📝 [ToolVersionsManager] 语言 \(languageId) 不存在于配置中，无需删除")
            return true  // 不存在也算成功
        }
        
        print("🗑️ [ToolVersionsManager] 删除语言配置: \(languageId)")
        return writeAllVersions(versions)
    }
    
    /// 删除多个语言的配置
    /// - Parameter languageIds: 语言ID数组
    /// - Returns: 是否成功
    static func removeVersions(for languageIds: [String]) -> Bool {
        var versions = readAllVersions()
        var removed = false
        
        for languageId in languageIds {
            if versions.removeValue(forKey: languageId) != nil {
                print("🗑️ [ToolVersionsManager] 删除语言配置: \(languageId)")
                removed = true
            }
        }
        
        guard removed else {
            return true  // 没有需要删除的也算成功
        }
        
        return writeAllVersions(versions)
    }
    
    // MARK: - 验证操作
    
    /// 验证指定语言的版本是否存在
    /// - Parameters:
    ///   - languageId: 语言ID
    ///   - version: 版本字符串
    /// - Returns: 是否匹配
    static func verifyVersion(for languageId: String, version: String) -> Bool {
        guard let currentVersion = readVersion(for: languageId) else {
            return false
        }
        return currentVersion == version
    }
    
    /// 检查文件是否存在
    /// - Returns: 是否存在
    static func fileExists() -> Bool {
        return FileManager.default.fileExists(atPath: filePath)
    }
}

// MARK: - Asdf Version Manager
// asdf 版本管理工具类 - 统一处理全局版本设置
class AsdfVersionManager {
    static let shared = AsdfVersionManager()
    
    private init() {}
    
    /// 检测 asdf 版本，确定使用哪个命令
    /// - Returns: true 表示使用 `asdf set -u`，false 表示使用 `asdf global`
    static func shouldUseSetCommand() -> Bool {
        let asdfVersionResult = Shell.run("asdf version 2>&1")
        return asdfVersionResult.out.contains("0.18") || 
               asdfVersionResult.out.contains("0.17") || 
               asdfVersionResult.out.contains("0.16")
    }
    
    /// 获取设置全局版本的命令
    /// - Parameters:
    ///   - tool: 工具名称
    ///   - version: 版本号
    /// - Returns: 命令字符串
    static func getGlobalCommand(tool: String, version: String) -> String {
        let useSetCommand = shouldUseSetCommand()
        return useSetCommand ? "asdf set -u \(tool) \(version)" : "asdf global \(tool) \(version)"
    }
    
    /// 设置工具的全局版本（统一入口）
    /// - Parameters:
    ///   - tool: 工具名称
    ///   - version: 版本号
    ///   - installIfMissing: 如果版本未安装是否自动安装
    /// - Returns: (成功与否, 日志消息)
    static func setGlobalVersion(tool: String, version: String, installIfMissing: Bool = true) -> (Bool, String) {
        // 1. 检查插件是否已安装
        let pluginCheck = Shell.run("asdf plugin list 2>/dev/null | grep -q '\(tool)' && echo 'installed' || echo 'not-installed'")
        if pluginCheck.out.contains("not-installed") {
            // 尝试安装插件
            let pluginAddCommand: String
            if tool == "php" {
                pluginAddCommand = "asdf plugin add php https://github.com/asdf-community/asdf-php.git"
            } else {
                pluginAddCommand = "asdf plugin add \(tool)"
            }
            
            let installPluginResult = Shell.run("\(pluginAddCommand) 2>&1")
            if installPluginResult.code != 0 {
                return (false, "❌ [\(tool)] 插件未安装且安装失败: \(installPluginResult.err)\n")
            }
        }
        
        // 2. 检查版本是否已安装
        let checkResult = Shell.run("asdf list \(tool) 2>/dev/null | grep -q '\(version)' && echo 'installed' || echo 'not-installed'")
        
        if checkResult.out.contains("not-installed") && installIfMissing {
            // 尝试安装版本
            let installResult = Shell.run("asdf install \(tool) \(version) 2>&1")
            if installResult.code != 0 {
                var errorMsg = installResult.err.trimmingCharacters(in: .whitespacesAndNewlines)
                if errorMsg.isEmpty {
                    errorMsg = installResult.out.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                // 对于 Java，检查可用版本
                if tool == "java" && errorMsg.contains("Unknown release") {
                    let availableVersions = Shell.run("asdf list all java 2>/dev/null | grep -E 'temurin|zulu|corretto' | head -5")
                    if !availableVersions.out.isEmpty {
                        let versionList = availableVersions.out.components(separatedBy: "\n").filter { !$0.isEmpty }.prefix(5).joined(separator: ", ")
                        errorMsg += "\n可用版本示例: \(versionList)"
                    }
                }
                
                return (false, "❌ [\(tool)] 安装版本 \(version) 失败: \(errorMsg)\n")
            }
        } else if checkResult.out.contains("not-installed") {
            return (false, "❌ [\(tool)] 版本 \(version) 未安装。请先运行 'asdf install \(tool) \(version)'\n")
        }
        
        // 3. 设置全局版本
        let globalCommand = getGlobalCommand(tool: tool, version: version)
        let setResult = Shell.run("\(globalCommand) 2>&1")
        
        if setResult.code == 0 {
            // 刷新 shims
            _ = Shell.run("asdf reshim \(tool) 2>/dev/null")
            return (true, "✅ [\(tool)] 已切换到版本 \(version)\n")
        } else {
            // 提供更详细的错误信息
            var errorMsg = setResult.err.trimmingCharacters(in: .whitespacesAndNewlines)
            if errorMsg.isEmpty {
                errorMsg = setResult.out.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            // 检查是否是 asdf 版本不兼容的问题
            if errorMsg.contains("invalid command") || errorMsg.contains("global") {
                // 尝试使用备选方案
                let useSetCommand = shouldUseSetCommand()
                let fallbackCommand = useSetCommand ? "asdf global \(tool) \(version)" : "asdf set -u \(tool) \(version)"
                let fallbackResult = Shell.run("\(fallbackCommand) 2>&1")
                if fallbackResult.code == 0 {
                    _ = Shell.run("asdf reshim \(tool) 2>/dev/null")
                    return (true, "✅ [\(tool)] 已切换到版本 \(version)（使用备选命令）\n")
                }
                errorMsg = "asdf 命令执行失败，请检查 asdf 版本：asdf version"
            } else if errorMsg.isEmpty {
                // 检查版本是否真的存在
                let verifyResult = Shell.run("asdf list \(tool) 2>/dev/null | grep -w '\(version)' || echo 'not-found'")
                if verifyResult.out.contains("not-found") {
                    errorMsg = "版本 \(version) 未安装。请先运行 'asdf install \(tool) \(version)'"
                } else {
                    errorMsg = "未知错误（退出码: \(setResult.code)）"
                }
            }
            
            return (false, "❌ [\(tool)] 切换到版本 \(version) 失败: \(errorMsg)\n")
        }
    }
}

