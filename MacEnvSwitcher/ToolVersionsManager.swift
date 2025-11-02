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

