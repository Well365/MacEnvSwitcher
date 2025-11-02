import Foundation

/// Shell 配置文件管理器
/// 负责管理各种 shell 配置文件（.zshrc, .bashrc, .bash_profile, .zprofile, .profile）中的环境变量配置
class ShellConfigManager {
    
    /// 所有支持的 shell 配置文件路径
    static var configFiles: [String] {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(homeDir)/.zshrc",
            "\(homeDir)/.bashrc",
            "\(homeDir)/.bash_profile",
            "\(homeDir)/.zprofile",
            "\(homeDir)/.profile"
        ]
    }
    
    // MARK: - 系统版本配置管理
    
    /// 配置块的开始标记
    private static func configStartMarker(languageId: String) -> String {
        return "# MacEnvSwitcher: System \(languageId) version configuration"
    }
    
    /// 配置块的结束标记
    private static func configEndMarker(languageId: String) -> String {
        return "# End MacEnvSwitcher system \(languageId) configuration"
    }
    
    /// 在指定的 shell 配置文件中设置系统版本的环境变量
    /// - Parameters:
    ///   - configPath: 配置文件路径
    ///   - envConfig: 环境变量字典
    ///   - languageId: 语言ID
    ///   - installPath: 安装路径
    /// - Returns: 是否成功
    static func setSystemVersionConfig(configPath: String, envConfig: [String: String], languageId: String, installPath: String) -> Bool {
        let fileManager = FileManager.default
        
        // 如果文件不存在，创建它
        if !fileManager.fileExists(atPath: configPath) {
            try? "".write(toFile: configPath, atomically: true, encoding: .utf8)
        }
        
        // 读取文件内容
        guard var content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            print("❌ [ShellConfigManager] 无法读取文件: \(configPath)")
            return false
        }
        
        let isZshrc = configPath.hasSuffix(".zshrc")
        let markerStart = configStartMarker(languageId: languageId)
        let markerEnd = configEndMarker(languageId: languageId)
        
        // 1. 移除该语言的所有旧配置块（避免重复）
        while let startRange = content.range(of: markerStart),
              let endRange = content.range(of: markerEnd, range: startRange.upperBound..<content.endIndex) {
            content.removeSubrange(startRange.lowerBound..<endRange.upperBound)
        }
        
        // 2. 构建环境变量配置块
        let configBlock = buildSystemVersionConfigBlock(envConfig: envConfig, languageId: languageId, installPath: installPath)
        
        // 3. 查找插入位置
        var updatedContent = content
        
        if isZshrc {
            // 对于 .zshrc，确保 asdf 初始化存在
            ensureAsdfInZshrc()
            
            // 重新读取文件（因为 ensureAsdfInZshrc 可能修改了文件）
            guard let reloadedContent = try? String(contentsOfFile: configPath, encoding: .utf8) else {
                return false
            }
            updatedContent = reloadedContent
            
            // 再次移除旧配置（如果 ensureAsdfInZshrc 后还有残留）
            while let startRange = updatedContent.range(of: markerStart),
                  let endRange = updatedContent.range(of: markerEnd, range: startRange.upperBound..<updatedContent.endIndex) {
                updatedContent.removeSubrange(startRange.lowerBound..<endRange.upperBound)
            }
            
            // 查找插入位置：在 asdf 初始化块之后
            let asdfEndMarker = "# End MacEnvSwitcher asdf initialization"
            if let asdfEndRange = updatedContent.range(of: asdfEndMarker) {
                // 在 asdf 初始化之后插入
                let insertIndex = updatedContent.index(asdfEndRange.upperBound, offsetBy: 0)
                var newlineOffset = 0
                if updatedContent[insertIndex...].hasPrefix("\n") {
                    newlineOffset = 1
                }
                if newlineOffset == 0 {
                    updatedContent.insert("\n", at: insertIndex)
                }
                updatedContent.insert(contentsOf: configBlock, at: updatedContent.index(insertIndex, offsetBy: newlineOffset))
            } else {
                // 如果没有找到 asdf 初始化，追加到文件末尾
                if !updatedContent.hasSuffix("\n") {
                    updatedContent += "\n"
                }
                updatedContent += configBlock
            }
        } else {
            // 对于其他配置文件，直接追加到文件末尾
            if !updatedContent.hasSuffix("\n") {
                updatedContent += "\n"
            }
            updatedContent += configBlock
        }
        
        // 4. 写入文件
        do {
            try updatedContent.write(toFile: configPath, atomically: true, encoding: .utf8)
            let fileName = (configPath as NSString).lastPathComponent
            print("✅ [ShellConfigManager] 已写入 \(fileName): \(languageId) 环境变量配置")
            return true
        } catch {
            print("❌ [ShellConfigManager] 写入 \(configPath) 失败: \(error)")
            return false
        }
    }
    
    /// 构建系统版本配置块
    private static func buildSystemVersionConfigBlock(envConfig: [String: String], languageId: String, installPath: String) -> String {
        var envLines: [String] = []
        var pathToPrepend: String? = nil
        
        // 提取 PATH 和环境变量
        for (key, value) in envConfig {
            if key == "PATH" {
                pathToPrepend = value.replacingOccurrences(of: "$PATH", with: "").trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            } else {
                envLines.append("export \(key)=\"\(value)\"")
            }
        }
        
        // 处理 PATH（确保系统版本路径在最前面）
        if let pathPrefix = pathToPrepend {
            envLines.append("")
            envLines.append("# 确保系统 \(languageId) 版本的 bin 目录在 PATH 最前面")
            
            // 根据语言类型，构建 PATH 清理命令
            let pathCommand = buildPathCommand(languageId: languageId, pathPrefix: pathPrefix)
            envLines.append(pathCommand)
        }
        
        let markerStart = configStartMarker(languageId: languageId)
        let markerEnd = configEndMarker(languageId: languageId)
        
        return """
        \(markerStart)
        \(envLines.joined(separator: "\n"))
        \(markerEnd)
        
        """
    }
    
    /// 构建 PATH 清理命令
    private static func buildPathCommand(languageId: String, pathPrefix: String) -> String {
        switch languageId {
        case "java":
            return "export PATH=\"$JAVA_HOME/bin:\"$(echo $PATH | tr ':' '\\n' | grep -v \"\\.asdf/shims\" | grep -v \"/Library/Java/JavaVirtualMachines\" | grep -v \"/System/Library/Frameworks/JavaVM.framework\" | grep -v \"/opt/homebrew/Cellar/openjdk\" | grep -v \"/opt/homebrew/opt/openjdk\" | grep -v \"/opt/homebrew/bin/java\" | grep -v \"/usr/local/opt/openjdk\" | grep -v \"/usr/local/Cellar/openjdk\" | grep -v \"/usr/local/bin/java\" | grep -vE \"(JavaVirtualMachines|JavaVM|jdk-|jdk1|openjdk)\" | grep -v \"$JAVA_HOME/bin\" | tr '\\n' ':' | sed 's/:$//' | sed 's/^://')"
            
        case "golang", "go":
            let pathsToRemove = "/usr/local/go|/opt/homebrew/opt/go|/opt/homebrew/bin/go"
            return "export PATH=\"\(pathPrefix):\"$(echo $PATH | tr ':' '\\n' | grep -vE \"\(pathsToRemove)\" | grep -v \"\\.asdf/shims\" | grep -v \"^\(pathPrefix)$\" | tr '\\n' ':' | sed 's/:$//' | sed 's/^://')"
            
        case "python":
            let pathsToRemove = "/usr/local/opt/python|/opt/homebrew/opt/python|/Library/Frameworks/Python.framework"
            return "export PATH=\"\(pathPrefix):\"$(echo $PATH | tr ':' '\\n' | grep -vE \"\(pathsToRemove)\" | grep -v \"\\.asdf/shims\" | grep -v \"^\(pathPrefix)$\" | tr '\\n' ':' | sed 's/:$//' | sed 's/^://')"
            
        case "ruby":
            let pathsToRemove = "/usr/local/opt/ruby|/opt/homebrew/opt/ruby|/System/Library/Frameworks/Ruby.framework"
            return "export PATH=\"\(pathPrefix):\"$(echo $PATH | tr ':' '\\n' | grep -vE \"\(pathsToRemove)\" | grep -v \"\\.asdf/shims\" | grep -v \"^\(pathPrefix)$\" | tr '\\n' ':' | sed 's/:$//' | sed 's/^://')"
            
        case "php":
            let pathsToRemove = "/usr/local/opt/php|/opt/homebrew/opt/php"
            return "export PATH=\"\(pathPrefix):\"$(echo $PATH | tr ':' '\\n' | grep -vE \"\(pathsToRemove)\" | grep -v \"\\.asdf/shims\" | grep -v \"^\(pathPrefix)$\" | tr '\\n' ':' | sed 's/:$//' | sed 's/^://')"
            
        case "nodejs":
            let pathsToRemove = "/usr/local/opt/node|/opt/homebrew/opt/node|/usr/local/lib/node_modules"
            return "export PATH=\"\(pathPrefix):\"$(echo $PATH | tr ':' '\\n' | grep -vE \"\(pathsToRemove)\" | grep -v \"\\.asdf/shims\" | grep -v \"^\(pathPrefix)$\" | tr '\\n' ':' | sed 's/:$//' | sed 's/^://')"
            
        default:
            // 通用处理：去重并前置新路径，移除 asdf shims
            return "export PATH=\"\(pathPrefix):\"$(echo $PATH | tr ':' '\\n' | grep -v \"\\.asdf/shims\" | awk '!seen[$0]++' | grep -v \"^\(pathPrefix)$\" | tr '\\n' ':' | sed 's/:$//' | sed 's/^://')"
        }
    }
    
    /// 在所有 shell 配置文件中设置系统版本配置
    /// - Parameters:
    ///   - envConfig: 环境变量字典
    ///   - languageId: 语言ID
    ///   - installPath: 安装路径
    /// - Returns: 是否成功（至少成功写入一个文件）
    static func setSystemVersionConfigInAllFiles(envConfig: [String: String], languageId: String, installPath: String) -> Bool {
        var success = false
        for configPath in configFiles {
            if setSystemVersionConfig(configPath: configPath, envConfig: envConfig, languageId: languageId, installPath: installPath) {
                success = true
            }
        }
        return success
    }
    
    /// 从指定配置文件中删除系统版本配置
    /// - Parameters:
    ///   - configPath: 配置文件路径
    ///   - languageId: 语言ID
    /// - Returns: 是否成功
    static func removeSystemVersionConfig(configPath: String, languageId: String) -> Bool {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: configPath),
              var content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return true  // 文件不存在也算成功
        }
        
        let markerStart = configStartMarker(languageId: languageId)
        let markerEnd = configEndMarker(languageId: languageId)
        var modified = false
        
        // 查找并删除配置块
        while let startRange = content.range(of: markerStart),
              let endRange = content.range(of: markerEnd, range: startRange.upperBound..<content.endIndex) {
            content.removeSubrange(startRange.lowerBound..<endRange.upperBound)
            modified = true
            let fileName = (configPath as NSString).lastPathComponent
            print("🗑️ [ShellConfigManager] 已从 \(fileName) 中删除系统 \(languageId) 版本配置块")
        }
        
        guard modified else {
            return true  // 没有需要删除的也算成功
        }
        
        // 写入更新后的内容
        do {
            try content.write(toFile: configPath, atomically: true, encoding: .utf8)
            return true
        } catch {
            print("❌ [ShellConfigManager] 更新 \(configPath) 失败: \(error)")
            return false
        }
    }
    
    /// 从所有 shell 配置文件中删除系统版本配置
    /// - Parameter languageId: 语言ID
    /// - Returns: 是否成功
    static func removeSystemVersionConfigFromAllFiles(languageId: String) -> Bool {
        var success = true
        for configPath in configFiles {
            if !removeSystemVersionConfig(configPath: configPath, languageId: languageId) {
                success = false
            }
        }
        return success
    }
    
    // MARK: - 检测操作
    
    /// 检查是否存在系统版本配置
    /// - Parameter languageId: 语言ID
    /// - Returns: 是否存在
    static func hasSystemVersionConfig(languageId: String) -> Bool {
        for configPath in configFiles {
            if hasSystemVersionConfig(configPath: configPath, languageId: languageId) {
                return true
            }
        }
        return false
    }
    
    /// 检查指定文件中是否存在系统版本配置
    /// - Parameters:
    ///   - configPath: 配置文件路径
    ///   - languageId: 语言ID
    /// - Returns: 是否存在
    static func hasSystemVersionConfig(configPath: String, languageId: String) -> Bool {
        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return false
        }
        return content.contains(configStartMarker(languageId: languageId))
    }
    
    /// 从配置文件中检测系统版本
    /// - Parameter languageId: 语言ID
    /// - Returns: 版本字符串，如果无法检测返回 nil
    static func detectSystemVersion(languageId: String) -> String? {
        let zshrcPath = configFiles.first { $0.hasSuffix(".zshrc") } ?? configFiles[0]
        
        guard let content = try? String(contentsOfFile: zshrcPath, encoding: .utf8) else {
            return nil
        }
        
        let markerStart = configStartMarker(languageId: languageId)
        let markerEnd = configEndMarker(languageId: languageId)
        
        guard let startRange = content.range(of: markerStart),
              let endRange = content.range(of: markerEnd, range: startRange.upperBound..<content.endIndex) else {
            return nil
        }
        
        let configBlock = String(content[startRange.lowerBound..<endRange.upperBound])
        
        // 根据语言类型提取版本信息
        switch languageId {
        case "java":
            // 查找 JAVA_HOME 路径，提取版本号
            if let javaHomeMatch = configBlock.range(of: #"export JAVA_HOME="([^"]+)""#, options: .regularExpression) {
                let javaHomeLine = String(configBlock[javaHomeMatch])
                let javaHomePath = javaHomeLine.replacingOccurrences(of: "export JAVA_HOME=\"", with: "").replacingOccurrences(of: "\"", with: "")
                // 从路径中提取版本号
                if let versionMatch = javaHomePath.range(of: #"jdk-(\d+\.\d+\.\d+)"#, options: .regularExpression) {
                    return String(javaHomePath[versionMatch]).replacingOccurrences(of: "jdk-", with: "")
                } else if let versionMatch = javaHomePath.range(of: #"jdk(\d+\.\d+\.\d+)"#, options: .regularExpression) {
                    return String(javaHomePath[versionMatch]).replacingOccurrences(of: "jdk", with: "")
                }
                // 尝试从路径中提取版本（如 jdk-11.0.21.jdk）
                if javaHomePath.contains("jdk-") {
                    let components = javaHomePath.components(separatedBy: "/")
                    for component in components {
                        if component.contains("jdk-") {
                            let parts = component.replacingOccurrences(of: ".jdk", with: "").components(separatedBy: "-")
                            if parts.count >= 2 {
                                return parts[1]
                            }
                        }
                    }
                }
            }
            
        default:
            break
        }
        
        return nil
    }
    
    // MARK: - asdf 初始化管理
    
    /// 确保 .zshrc 文件中包含 asdf 初始化
    static func ensureAsdfInZshrc() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let zshrcPath = "\(homeDir)/.zshrc"
        let fileManager = FileManager.default
        
        // 如果文件不存在，创建它
        if !fileManager.fileExists(atPath: zshrcPath) {
            try? "".write(toFile: zshrcPath, atomically: true, encoding: .utf8)
        }
        
        // 读取文件内容
        guard var content = try? String(contentsOfFile: zshrcPath, encoding: .utf8) else {
            return
        }
        
        // asdf 初始化代码块
        let asdfInitBlock = """
        # MacEnvSwitcher: asdf initialization
        if [ -d "$HOME/.asdf" ]; then
            export ASDF_DIR="$HOME/.asdf"
            export PATH="$HOME/.asdf/shims:$HOME/.asdf/bin:$PATH"
            [ -s "$HOME/.asdf/asdf.sh" ] && source "$HOME/.asdf/asdf.sh"
            [ -s "$HOME/.asdf/completions/asdf.bash" ] && source "$HOME/.asdf/completions/asdf.bash"
        elif [ -d "/opt/homebrew/opt/asdf" ]; then
            export ASDF_DIR="/opt/homebrew/opt/asdf"
            export PATH="/opt/homebrew/opt/asdf/shims:/opt/homebrew/opt/asdf/bin:$PATH"
            source "/opt/homebrew/opt/asdf/libexec/asdf.sh"
            source "/opt/homebrew/opt/asdf/etc/bash_completion.d/asdf.bash" 2>/dev/null || true
        elif command -v brew >/dev/null 2>&1; then
            ASDF_SH=$(brew --prefix asdf 2>/dev/null)/libexec/asdf.sh
            if [ -f "$ASDF_SH" ]; then
                export ASDF_DIR=$(brew --prefix asdf 2>/dev/null)
                export PATH="$ASDF_DIR/shims:$ASDF_DIR/bin:$PATH"
                source "$ASDF_SH"
            fi
        fi
        # End MacEnvSwitcher asdf initialization

        """
        
        // 分析文件内容，检查是否已包含 asdf 初始化
        let asdfMarkers = [
            "# MacEnvSwitcher: asdf initialization",
            "# End MacEnvSwitcher asdf initialization",
            "source \"$HOME/.asdf/asdf.sh\"",
            "source \"$HOME/.asdf/completions/asdf.bash\"",
            "source \"/opt/homebrew/opt/asdf/libexec/asdf.sh\"",
            "$(brew --prefix asdf)/libexec/asdf.sh"
        ]
        
        var hasAsdfInit = false
        var hasMacEnvSwitcherMarker = false
        var startMarkerIndex: String.Index?
        var endMarkerIndex: String.Index?
        
        // 检查是否有 MacEnvSwitcher 标记
        if let startRange = content.range(of: "# MacEnvSwitcher: asdf initialization"),
           let endRange = content.range(of: "# End MacEnvSwitcher asdf initialization") {
            hasMacEnvSwitcherMarker = true
            startMarkerIndex = startRange.lowerBound
            endMarkerIndex = endRange.upperBound
        }
        
        // 检查是否有其他形式的 asdf 初始化
        for marker in asdfMarkers {
            if content.contains(marker) {
                hasAsdfInit = true
                break
            }
        }
        
        // 如果已有 MacEnvSwitcher 标记的初始化，不需要添加
        if hasMacEnvSwitcherMarker {
            print("✅ [ShellConfigManager] asdf 初始化已存在（MacEnvSwitcher）")
            return
        }
        
        // 如果已有其他形式的 asdf 初始化，不需要添加
        if hasAsdfInit {
            print("✅ [ShellConfigManager] asdf 初始化已存在（其他形式）")
            return
        }
        
        // 添加 asdf 初始化
        if !content.hasSuffix("\n") {
            content += "\n"
        }
        content += asdfInitBlock
        
        do {
            try content.write(toFile: zshrcPath, atomically: true, encoding: .utf8)
            print("✅ [ShellConfigManager] 已添加 asdf 初始化到 .zshrc")
        } catch {
            print("❌ [ShellConfigManager] 写入 .zshrc 失败: \(error)")
        }
    }
}

