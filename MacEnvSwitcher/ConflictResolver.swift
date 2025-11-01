import Foundation

// 版本管理器冲突检测和解决方案
class ConflictResolver: ObservableObject {
    static let shared = ConflictResolver()
    
    enum ConflictSeverity {
        case low        // 可以共存，但可能有路径优先级问题
        case medium     // 有功能重叠，建议选择一个
        case high       // 严重冲突，必须解决
        case critical   // 会导致系统不稳定
    }
    
    struct ConflictResolution {
        let issue: ConflictInfo
        let severity: ConflictSeverity
        let recommendations: [String]
        let automaticSolution: String?
        let manualSteps: [String]
        let rollbackPlan: String?
    }
    
    private init() {}
    
    // MARK: - Main Conflict Detection
    
    /// 检测所有版本管理器冲突
    func detectAllConflicts() -> [ConflictResolution] {
        let detectors = Detectors()
        let conflicts = detectors.checkVersionManagerConflicts()
        
        var resolutions: [ConflictResolution] = []
        
        for conflict in conflicts {
            let resolution = analyzeConflict(conflict)
            resolutions.append(resolution)
        }
        
        // 检查PATH顺序问题
        let pathIssues = checkPATHConflicts()
        resolutions.append(contentsOf: pathIssues)
        
        // 检查环境变量冲突
        let envIssues = checkEnvironmentVariableConflicts()
        resolutions.append(contentsOf: envIssues)
        
        return resolutions.sorted { $0.severity.priority > $1.severity.priority }
    }
    
    /// 分析单个冲突
    private func analyzeConflict(_ conflict: ConflictInfo) -> ConflictResolution {
        let severity = determineSeverity(for: conflict)
        let recommendations = generateRecommendations(for: conflict)
        let automaticSolution = generateAutomaticSolution(for: conflict)
        let manualSteps = generateManualSteps(for: conflict)
        let rollbackPlan = generateRollbackPlan(for: conflict)
        
        return ConflictResolution(
            issue: conflict,
            severity: severity,
            recommendations: recommendations,
            automaticSolution: automaticSolution,
            manualSteps: manualSteps,
            rollbackPlan: rollbackPlan
        )
    }
    
    // MARK: - Conflict Analysis
    
    /// 确定冲突严重程度
    private func determineSeverity(for conflict: ConflictInfo) -> ConflictSeverity {
        let managerCount = conflict.managers.count
        
        // 特殊情况：某些组合特别危险
        if conflict.managers.contains("rvm") && conflict.managers.contains("rbenv") {
            return .critical
        }
        
        if conflict.managers.contains("nvm") && conflict.managers.contains("asdf") && conflict.managers.contains("homebrew") {
            return .high
        }
        
        switch managerCount {
        case 0, 1:
            return .low
        case 2:
            return conflict.managers.contains("asdf") ? .medium : .high
        case 3:
            return .high
        default:
            return .critical
        }
    }
    
    /// 生成解决建议
    private func generateRecommendations(for conflict: ConflictInfo) -> [String] {
        var recommendations: [String] = []
        
        recommendations.append("推荐使用 asdf 作为统一的版本管理器")
        
        if conflict.managers.contains("asdf") {
            recommendations.append("您已经安装了 asdf，建议卸载其他版本管理器")
        } else {
            recommendations.append("建议安装 asdf 并迁移现有配置")
        }
        
        // 针对特定工具的建议
        switch conflict.tool {
        case "Node.js":
            if conflict.managers.contains("nvm") {
                recommendations.append("可以保留 nvm 用于特定项目，但设置 asdf 为默认")
            }
            if conflict.managers.contains("homebrew") {
                recommendations.append("建议卸载 Homebrew 安装的 Node.js 以避免PATH冲突")
            }
            
        case "Python":
            if conflict.managers.contains("pyenv") {
                recommendations.append("可以考虑从 pyenv 迁移到 asdf，或者明确设置PATH优先级")
            }
            if conflict.managers.contains("conda") {
                recommendations.append("Conda 可以与 asdf 并存，但需要注意环境变量设置")
            }
            
        case "Ruby":
            if conflict.managers.contains("rvm") {
                recommendations.append("强烈建议从 RVM 迁移到 asdf，RVM 会修改很多系统设置")
            }
            if conflict.managers.contains("rbenv") {
                recommendations.append("rbenv 与 asdf 功能重叠，建议选择其一")
            }
            
        case "Java":
            if conflict.managers.contains("jabba") {
                recommendations.append("jabba 是优秀的Java版本管理器，可以与 asdf 并存")
            }
            if conflict.managers.contains("system") {
                recommendations.append("建议保留系统Java作为fallback，但优先使用版本管理器")
            }
            
        default:
            break
        }
        
        return recommendations
    }
    
    /// 生成自动解决方案
    private func generateAutomaticSolution(for conflict: ConflictInfo) -> String? {
        if conflict.managers.contains("asdf") && conflict.managers.count == 2 {
            let otherManager = conflict.managers.first { $0 != "asdf" }
            
            switch otherManager {
            case "homebrew":
                return "自动卸载Homebrew安装的\(conflict.tool)，保留asdf管理的版本"
            case "nvm":
                return "自动配置PATH，使asdf优先于nvm"
            case "pyenv":
                return "自动配置shell，使asdf优先于pyenv"
            default:
                return nil
            }
        }
        
        return nil
    }
    
    /// 生成手动解决步骤
    private func generateManualSteps(for conflict: ConflictInfo) -> [String] {
        var steps: [String] = []
        
        steps.append("1. 备份当前配置")
        steps.append("   cp ~/.zshrc ~/.zshrc.backup")
        steps.append("   cp ~/.bashrc ~/.bashrc.backup 2>/dev/null || true")
        
        if !conflict.managers.contains("asdf") {
            steps.append("2. 安装 asdf")
            steps.append("   brew install asdf")
            steps.append("   echo '. $(brew --prefix asdf)/libexec/asdf.sh' >> ~/.zshrc")
        }
        
        steps.append("3. 安装 asdf 插件")
        steps.append("   asdf plugin add \(pluginName(for: conflict.tool))")
        
        // 针对特定管理器的清理步骤
        for manager in conflict.managers {
            switch manager {
            case "nvm":
                steps.append("4. 清理 nvm（可选）")
                steps.append("   # 注释掉 ~/.zshrc 中的 nvm 初始化代码")
                steps.append("   # 或者调整PATH顺序，使asdf优先")
                
            case "pyenv":
                steps.append("4. 清理 pyenv（可选）")
                steps.append("   # 注释掉 ~/.zshrc 中的 pyenv 初始化代码")
                steps.append("   # 或者 brew uninstall pyenv")
                
            case "rbenv":
                steps.append("4. 清理 rbenv（可选）")
                steps.append("   brew uninstall rbenv")
                steps.append("   # 从 ~/.zshrc 中删除 rbenv 初始化代码")
                
            case "rvm":
                steps.append("4. 清理 RVM（推荐）")
                steps.append("   rvm implode")
                steps.append("   # 手动清理 ~/.zshrc 中的 RVM 代码")
                
            case "homebrew":
                steps.append("4. 卸载 Homebrew 版本")
                steps.append("   brew uninstall \(homebrewPackageName(for: conflict.tool))")
                
            default:
                break
            }
        }
        
        steps.append("5. 重新安装所需版本")
        steps.append("   asdf install \(pluginName(for: conflict.tool)) latest")
        steps.append("   asdf global \(pluginName(for: conflict.tool)) latest")
        
        steps.append("6. 验证配置")
        steps.append("   source ~/.zshrc")
        steps.append("   which \(toolBinaryName(for: conflict.tool))")
        steps.append("   \(toolBinaryName(for: conflict.tool)) --version")
        
        return steps
    }
    
    /// 生成回滚计划
    private func generateRollbackPlan(for conflict: ConflictInfo) -> String? {
        return """
        如果出现问题，可以按照以下步骤回滚：
        1. 恢复配置文件备份
           cp ~/.zshrc.backup ~/.zshrc
           cp ~/.bashrc.backup ~/.bashrc 2>/dev/null || true
        2. 重新启动终端
        3. 如果需要，重新安装被卸载的工具
        4. 联系技术支持获取进一步帮助
        """
    }
    
    // MARK: - PATH Conflict Detection
    
    private func checkPATHConflicts() -> [ConflictResolution] {
        let detectors = Detectors()
        let pathAnalysis = detectors.checkPATHPriority()
        
        var conflicts: [ConflictResolution] = []
        
        for (tool, paths) in pathAnalysis {
            if paths.count > 1 {
                // 检查是否有优先级问题
                let hasConflict = checkForPriorityIssues(tool: tool, paths: paths)
                
                if hasConflict {
                    let conflictInfo = ConflictInfo(
                        tool: tool,
                        managers: extractManagersFromPaths(paths),
                        recommended: "asdf",
                        pathConflicts: paths,
                        envConflicts: [:]
                    )
                    
                    let resolution = ConflictResolution(
                        issue: conflictInfo,
                        severity: .medium,
                        recommendations: ["调整PATH顺序，使推荐的版本管理器优先"],
                        automaticSolution: "自动调整PATH顺序",
                        manualSteps: generatePATHFixSteps(tool: tool, paths: paths),
                        rollbackPlan: "恢复原PATH配置"
                    )
                    
                    conflicts.append(resolution)
                }
            }
        }
        
        return conflicts
    }
    
    private func checkForPriorityIssues(tool: String, paths: [String]) -> Bool {
        // 简化的检查：如果asdf不在第一位，就认为有优先级问题
        let firstPath = paths.first ?? ""
        return !firstPath.contains("asdf") && paths.contains { $0.contains("asdf") }
    }
    
    private func extractManagersFromPaths(_ paths: [String]) -> [String] {
        var managers: [String] = []
        
        for path in paths {
            if path.contains("asdf") {
                managers.append("asdf")
            } else if path.contains("homebrew") || path.contains("/opt/homebrew") {
                managers.append("homebrew")
            } else if path.contains(".nvm") {
                managers.append("nvm")
            } else if path.contains(".pyenv") {
                managers.append("pyenv")
            } else if path.contains(".rbenv") {
                managers.append("rbenv")
            } else if path.contains("/usr/bin") {
                managers.append("system")
            }
        }
        
        return Array(Set(managers))
    }
    
    private func generatePATHFixSteps(tool: String, paths: [String]) -> [String] {
        return [
            "1. 检查当前PATH",
            "   echo $PATH | tr ':' '\\n'",
            "2. 编辑shell配置文件",
            "   nano ~/.zshrc",
            "3. 调整PATH顺序，确保asdf优先",
            "   # 将asdf相关的PATH移到最前面",
            "4. 重新加载配置",
            "   source ~/.zshrc",
            "5. 验证优先级",
            "   which \(toolBinaryName(for: tool))"
        ]
    }
    
    // MARK: - Environment Variable Conflicts
    
    private func checkEnvironmentVariableConflicts() -> [ConflictResolution] {
        let detectors = Detectors()
        let envConflicts = detectors.checkEnvironmentVariableConflicts()
        
        var conflicts: [ConflictResolution] = []
        
        for (envVar, values) in envConflicts {
            if values.count > 1 || isProblematicEnvVar(envVar, value: values.first ?? "") {
                let conflictInfo = ConflictInfo(
                    tool: "Environment Variables",
                    managers: ["system"],
                    recommended: "asdf managed",
                    pathConflicts: [],
                    envConflicts: [envVar: values]
                )
                
                let resolution = ConflictResolution(
                    issue: conflictInfo,
                    severity: determineEnvVarSeverity(envVar),
                    recommendations: generateEnvVarRecommendations(envVar),
                    automaticSolution: nil,
                    manualSteps: generateEnvVarFixSteps(envVar, values: values),
                    rollbackPlan: "恢复原环境变量设置"
                )
                
                conflicts.append(resolution)
            }
        }
        
        return conflicts
    }
    
    private func isProblematicEnvVar(_ envVar: String, value: String) -> Bool {
        switch envVar {
        case "JAVA_HOME":
            return !value.contains("asdf") && !value.isEmpty
        case "PYTHONPATH":
            return !value.isEmpty // PYTHONPATH 通常不应该设置
        case "NODE_PATH":
            return !value.isEmpty // NODE_PATH 通常不应该设置
        default:
            return false
        }
    }
    
    private func determineEnvVarSeverity(_ envVar: String) -> ConflictSeverity {
        switch envVar {
        case "JAVA_HOME", "PYTHONPATH":
            return .high
        case "NODE_PATH", "VIRTUAL_ENV":
            return .medium
        default:
            return .low
        }
    }
    
    private func generateEnvVarRecommendations(_ envVar: String) -> [String] {
        switch envVar {
        case "JAVA_HOME":
            return [
                "让 asdf 自动管理 JAVA_HOME",
                "在 shell 配置中设置：export JAVA_HOME=\"$(asdf where java)\""
            ]
        case "PYTHONPATH":
            return [
                "通常不需要设置 PYTHONPATH",
                "使用虚拟环境管理 Python 依赖"
            ]
        case "NODE_PATH":
            return [
                "不建议设置 NODE_PATH",
                "使用 npm/yarn 的本地安装机制"
            ]
        default:
            return ["检查是否真的需要这个环境变量"]
        }
    }
    
    private func generateEnvVarFixSteps(_ envVar: String, values: [String]) -> [String] {
        return [
            "1. 检查环境变量当前值",
            "   echo $\(envVar)",
            "2. 查找设置位置",
            "   grep -r '\(envVar)' ~/.zshrc ~/.bashrc ~/.bash_profile ~/.profile 2>/dev/null",
            "3. 根据建议修改或删除设置",
            "4. 重新加载shell配置",
            "   source ~/.zshrc"
        ]
    }
    
    // MARK: - Automatic Resolution
    
    /// 自动解决冲突
    func autoResolveConflicts() -> (resolved: Int, failed: Int, logs: [String]) {
        let conflicts = detectAllConflicts()
        var resolved = 0
        var failed = 0
        var logs: [String] = []
        
        for conflict in conflicts {
            if let solution = conflict.automaticSolution {
                logs.append("🔄 正在自动解决: \(conflict.issue.tool) - \(solution)")
                
                let success = executeAutomaticSolution(conflict)
                if success {
                    resolved += 1
                    logs.append("✅ 已解决: \(conflict.issue.tool)")
                } else {
                    failed += 1
                    logs.append("❌ 解决失败: \(conflict.issue.tool)")
                }
            } else {
                logs.append("⚠️ 需要手动解决: \(conflict.issue.tool)")
                failed += 1
            }
        }
        
        return (resolved, failed, logs)
    }
    
    /// 执行自动解决方案
    private func executeAutomaticSolution(_ conflict: ConflictResolution) -> Bool {
        switch conflict.issue.tool {
        case "Node.js":
            return resolveNodeJSConflict(conflict)
        case "Python":
            return resolvePythonConflict(conflict)
        case "Ruby":
            return resolveRubyConflict(conflict)
        case "Java":
            return resolveJavaConflict(conflict)
        default:
            return false
        }
    }
    
    private func resolveNodeJSConflict(_ conflict: ConflictResolution) -> Bool {
        if conflict.issue.managers.contains("homebrew") && conflict.issue.managers.contains("asdf") {
            // 卸载 Homebrew 的 Node.js
            let result = Shell.run("brew uninstall --ignore-dependencies node")
            return result.code == 0
        }
        return false
    }
    
    private func resolvePythonConflict(_ conflict: ConflictResolution) -> Bool {
        // 大多数Python冲突需要手动解决
        return false
    }
    
    private func resolveRubyConflict(_ conflict: ConflictResolution) -> Bool {
        if conflict.issue.managers.contains("homebrew") && conflict.issue.managers.contains("asdf") {
            let result = Shell.run("brew uninstall --ignore-dependencies ruby")
            return result.code == 0
        }
        return false
    }
    
    private func resolveJavaConflict(_ conflict: ConflictResolution) -> Bool {
        // Java冲突通常涉及系统级设置，需要谨慎处理
        return false
    }
    
    // MARK: - Utility Functions
    
    private func pluginName(for tool: String) -> String {
        switch tool.lowercased() {
        case "node.js", "nodejs": return "nodejs"
        case "python": return "python"
        case "ruby": return "ruby"
        case "java": return "java"
        case "go", "golang": return "golang"
        default: return tool.lowercased()
        }
    }
    
    private func homebrewPackageName(for tool: String) -> String {
        switch tool.lowercased() {
        case "node.js", "nodejs": return "node"
        case "python": return "python@3.12"
        case "ruby": return "ruby"
        case "java": return "openjdk"
        case "go", "golang": return "go"
        default: return tool.lowercased()
        }
    }
    
    private func toolBinaryName(for tool: String) -> String {
        switch tool.lowercased() {
        case "node.js", "nodejs": return "node"
        case "python": return "python3"
        case "ruby": return "ruby"
        case "java": return "java"
        case "go", "golang": return "go"
        default: return tool.lowercased()
        }
    }
}

// MARK: - Extensions

extension ConflictSeverity {
    var priority: Int {
        switch self {
        case .critical: return 4
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }
    
    var displayName: String {
        switch self {
        case .critical: return "严重"
        case .high: return "高"
        case .medium: return "中等"
        case .low: return "低"
        }
    }
    
    var emoji: String {
        switch self {
        case .critical: return "🚨"
        case .high: return "⚠️"
        case .medium: return "⚡"
        case .low: return "💡"
        }
    }
}