import SwiftUI

// 启动向导 - 检查并引导安装必需工具
struct SetupWizardView: View {
    @StateObject private var viewModel = SetupWizardViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text(tr("Environment Setup Wizard"))
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(tr("Installing required development tools for first-time use"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // 检查进度摘要
                    if viewModel.isChecking {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text(tr("Checking system environment..."))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                    } else {
                        HStack(spacing: 20) {
                            StatusBadge(
                                icon: "checkmark.circle.fill",
                                color: .green,
                                count: viewModel.installedCount,
                                label: tr("Installed")
                            )
                            
                            StatusBadge(
                                icon: "exclamationmark.circle.fill",
                                color: .orange,
                                count: viewModel.missingCount,
                                label: tr("Pending")
                            )
                            
                            StatusBadge(
                                icon: "xmark.circle.fill",
                                color: .red,
                                count: viewModel.errorCount,
                                label: tr("Error")
                            )
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.top, 40)
                .padding(.bottom, 30)
                
                // 必需工具列表
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(viewModel.requiredTools) { tool in
                            RequiredToolCard(tool: tool, viewModel: viewModel)
                        }
                    }
                    .padding()
                }
                
                Divider()
                
                // Bottom Actions
                HStack(spacing: 16) {
                    // 检查所有按钮
                    Button(action: {
                        viewModel.checkAllTools()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text(tr("Recheck All"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // 继续按钮
                    Button(action: {
                        if viewModel.canProceed {
                            dismiss()
                        }
                    }) {
                        HStack {
                            Text(tr("Continue"))
                            Image(systemName: "arrow.right")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.canProceed ? Color.green : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!viewModel.canProceed)
                }
                .padding()
            }
            .navigationTitle(tr("Setup Wizard"))
        }
        .frame(minWidth: 950, idealWidth: 1000, minHeight: 750, idealHeight: 800)
        .onAppear {
            viewModel.checkAllTools()
        }
    }
}

// 状态徽章组件
struct StatusBadge: View {
    let icon: String
    let color: Color
    let count: Int
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text("\(count)")
                    .font(.headline)
                    .fontWeight(.bold)
            }
            .foregroundColor(color)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(width: 70)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// 必需工具卡片
struct RequiredToolCard: View {
    let tool: RequiredTool
    @ObservedObject var viewModel: SetupWizardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // 状态图标
                Image(systemName: tool.status.icon)
                    .font(.title2)
                    .foregroundColor(tool.status.color)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(tool.name)
                        .font(.headline)
                    Text(tool.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 操作按钮
                if tool.status == .notInstalled || tool.status == .error {
                    Button(action: {
                        viewModel.installTool(tool)
                    }) {
                        if tool.isInstalling {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 80)
                        } else {
                            Text(tr("Install"))
                                .frame(width: 80)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(tool.isInstalling)
                } else if tool.status == .checking {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 80)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                }
            }
            
            // 详细信息
            if !tool.detailLog.isEmpty {
                Text(tool.detailLog)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 44)
            }
            
            // 安装提示
            if tool.status == .notInstalled || tool.status == .error {
                VStack(alignment: .leading, spacing: 4) {
                    if let tip = tool.installTip {
                        Text(tip)
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.leading, 44)
                    }
                    
                    if let manualSteps = tool.manualInstallSteps, !manualSteps.isEmpty {
                        DisclosureGroup(tr("Manual Installation Steps")) {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(manualSteps.enumerated()), id: \.offset) { index, step in
                                    Text("\(index + 1). \(step)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.top, 4)
                        }
                        .font(.caption)
                        .padding(.leading, 44)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(tool.status.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// 必需工具数据模型
struct RequiredTool: Identifiable {
    let id: String
    let name: String
    let description: String
    var status: ToolStatus = .checking
    var detailLog: String = ""
    var isInstalling: Bool = false
    var installTip: String?
    var manualInstallSteps: [String]?
    let priority: Int // 安装优先级
    
    enum ToolStatus {
        case checking
        case installed
        case notInstalled
        case error
        
        var icon: String {
            switch self {
            case .checking: return "arrow.clockwise.circle"
            case .installed: return "checkmark.circle.fill"
            case .notInstalled: return "exclamationmark.circle"
            case .error: return "xmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .checking: return .blue
            case .installed: return .green
            case .notInstalled: return .orange
            case .error: return .red
            }
        }
    }
}

// 视图模型
class SetupWizardViewModel: ObservableObject {
    @Published var requiredTools: [RequiredTool] = []
    @Published var canProceed: Bool = false
    @Published var isChecking: Bool = false
    
    var installedCount: Int {
        requiredTools.filter { $0.status == .installed }.count
    }
    
    var missingCount: Int {
        requiredTools.filter { $0.status == .notInstalled }.count
    }
    
    var errorCount: Int {
        requiredTools.filter { $0.status == .error }.count
    }
    
    private let installers = Installers()
    private let detectors = Detectors()
    
    init() {
        setupRequiredTools()
    }
    
    private func setupRequiredTools() {
        requiredTools = [
            RequiredTool(
                id: "xcode",
                name: "Xcode",
                description: "Apple 官方开发工具，iOS/macOS 开发必备",
                installTip: "Xcode 需要从 App Store 手动安装",
                manualInstallSteps: [
                    "打开 App Store",
                    "搜索 'Xcode'",
                    "点击 '获取' 或 '安装'",
                    "等待下载完成（文件较大，约 12GB）"
                ],
                priority: 1
            ),
            RequiredTool(
                id: "clt",
                name: "Command Line Tools",
                description: "Xcode 命令行工具，编译器和开发工具集",
                installTip: "点击安装按钮将自动弹出安装对话框",
                manualInstallSteps: [
                    "在终端运行: xcode-select --install",
                    "在弹出的对话框中点击 '安装'",
                    "等待安装完成"
                ],
                priority: 2
            ),
            RequiredTool(
                id: "brew",
                name: "Homebrew",
                description: "macOS 包管理器，安装和管理软件的核心工具",
                installTip: "自动安装，需要几分钟时间",
                manualInstallSteps: [
                    "在终端运行以下命令:",
                    "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"",
                    "按照提示输入密码",
                    "安装完成后重启终端"
                ],
                priority: 3
            ),
            RequiredTool(
                id: "oh-my-zsh",
                name: "Oh My Zsh",
                description: "强大的 Zsh 配置框架，提供更好的终端体验",
                installTip: "自动安装，会配置您的 .zshrc 文件",
                manualInstallSteps: [
                    "在终端运行:",
                    "sh -c \"$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\"",
                    "按提示完成安装"
                ],
                priority: 4
            ),
            RequiredTool(
                id: "asdf",
                name: "asdf",
                description: "统一的版本管理器，管理多种编程语言版本",
                installTip: "通过 Homebrew 自动安装",
                manualInstallSteps: [
                    "在终端运行: brew install asdf",
                    "添加到 shell 配置: echo '. $(brew --prefix asdf)/libexec/asdf.sh' >> ~/.zshrc",
                    "重启终端使配置生效"
                ],
                priority: 5
            )
        ]
    }
    
    func checkAllTools() {
        DispatchQueue.main.async {
            self.isChecking = true
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            for index in self.requiredTools.indices {
                self.checkTool(at: index)
            }
            
            DispatchQueue.main.async {
                self.isChecking = false
            }
            
            self.updateCanProceed()
        }
    }
    
    private func checkTool(at index: Int) {
        DispatchQueue.main.async {
            self.requiredTools[index].status = .checking
            self.requiredTools[index].detailLog = "正在检查..."
        }
        
        let tool = requiredTools[index]
        let result: CheckResult
        
        switch tool.id {
        case "xcode":
            result = checkXcode()
        case "clt":
            result = checkCommandLineTools()
        case "brew":
            result = checkHomebrew()
        case "oh-my-zsh":
            result = checkOhMyZsh()
        case "asdf":
            result = checkAsdf()
        default:
            result = CheckResult(ok: false, log: "未知工具", tip: nil)
        }
        
        DispatchQueue.main.async {
            self.requiredTools[index].status = result.ok ? .installed : .notInstalled
            self.requiredTools[index].detailLog = result.log
            if let tip = result.tip {
                self.requiredTools[index].installTip = tip
            }
        }
    }
    
    // 详细的检查方法
    private func checkXcode() -> CheckResult {
        let result = detectors.check(.xcode)
        if result.ok {
            // 尝试获取版本和路径
            let version = Shell.run("xcodebuild -version").out.trimmingCharacters(in: .whitespacesAndNewlines)
            let path = Shell.run("xcode-select -p").out.trimmingCharacters(in: .whitespacesAndNewlines)
            return CheckResult(
                ok: true,
                log: "✓ 已安装\n版本: \(version.components(separatedBy: "\n").first ?? "未知")\n路径: \(path)",
                tip: nil
            )
        }
        return CheckResult(ok: false, log: "✗ 未安装 - 需要从 App Store 安装", tip: "Xcode 是必需的开发工具")
    }
    
    private func checkCommandLineTools() -> CheckResult {
        let result = detectors.check(.clt)
        if result.ok {
            let version = Shell.run("xcode-select --version").out.trimmingCharacters(in: .whitespacesAndNewlines)
            let path = Shell.run("xcode-select -p").out.trimmingCharacters(in: .whitespacesAndNewlines)
            return CheckResult(
                ok: true,
                log: "✓ 已安装\n\(version)\n路径: \(path)",
                tip: nil
            )
        }
        return CheckResult(ok: false, log: "✗ 未安装 - 点击安装按钮进行安装", tip: "命令行工具包含编译器等必要工具")
    }
    
    private func checkHomebrew() -> CheckResult {
        let result = detectors.check(.brew)
        if result.ok {
            let version = Shell.run("brew --version").out.components(separatedBy: "\n").first ?? "未知版本"
            let path = Shell.run("which brew").out.trimmingCharacters(in: .whitespacesAndNewlines)
            return CheckResult(
                ok: true,
                log: "✓ 已安装\n版本: \(version)\n路径: \(path)",
                tip: nil
            )
        }
        return CheckResult(ok: false, log: "✗ 未安装 - 将通过官方脚本自动安装", tip: "Homebrew 是 macOS 最流行的包管理器")
    }
    
    private func checkOhMyZsh() -> CheckResult {
        let result = detectors.check(.ohMyBash)
        if result.ok {
            let omzPath = NSString(string: "~/.oh-my-zsh").expandingTildeInPath
            let themeFile = NSString(string: "~/.zshrc").expandingTildeInPath
            var theme = "未知"
            if let content = try? String(contentsOfFile: themeFile) {
                if let match = content.range(of: "ZSH_THEME=\"[^\"]+\"", options: .regularExpression) {
                    theme = String(content[match]).replacingOccurrences(of: "ZSH_THEME=", with: "").replacingOccurrences(of: "\"", with: "")
                }
            }
            return CheckResult(
                ok: true,
                log: "✓ 已安装\n路径: \(omzPath)\n主题: \(theme)",
                tip: nil
            )
        }
        return CheckResult(ok: false, log: "✗ 未安装 - 将通过官方脚本自动安装", tip: "Oh My Zsh 提供强大的终端配置")
    }
    
    private func checkAsdf() -> CheckResult {
        let result = detectors.check(.asdf)
        if result.ok {
            let version = Shell.run("asdf --version").out.trimmingCharacters(in: .whitespacesAndNewlines)
            let path = Shell.run("which asdf").out.trimmingCharacters(in: .whitespacesAndNewlines)
            let plugins = Shell.run("asdf plugin list").out.trimmingCharacters(in: .whitespacesAndNewlines)
            let pluginList = plugins.isEmpty ? "无" : plugins.replacingOccurrences(of: "\n", with: ", ")
            return CheckResult(
                ok: true,
                log: "✓ 已安装\n版本: \(version)\n路径: \(path)\n插件: \(pluginList)",
                tip: nil
            )
        }
        return CheckResult(ok: false, log: "✗ 未安装 - 将通过 Homebrew 自动安装", tip: "asdf 可以管理多种编程语言版本")
    }
    
    func installTool(_ tool: RequiredTool) {
        guard let index = requiredTools.firstIndex(where: { $0.id == tool.id }) else { return }
        
        DispatchQueue.main.async {
            self.requiredTools[index].isInstalling = true
            self.requiredTools[index].status = .checking
            self.requiredTools[index].detailLog = "安装中..."
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result: (Bool, String, String?)
            
            switch tool.id {
            case "xcode":
                // Xcode 只能手动安装
                self.installers.openXcodeAppStore()
                result = (false, "请在 App Store 中手动安装 Xcode", "Xcode 无法自动安装")
                
            case "clt":
                result = self.installers.install(.clt, autoYes: true)
                
            case "brew":
                result = self.installers.install(.brew, autoYes: true)
                
            case "oh-my-zsh":
                result = self.installers.install(.ohMyBash, autoYes: true)
                
            case "asdf":
                result = self.installers.install(.asdf, autoYes: true)
                
            default:
                result = (false, "未知工具", nil)
            }
            
            DispatchQueue.main.async {
                self.requiredTools[index].isInstalling = false
                self.requiredTools[index].status = result.0 ? .installed : .error
                self.requiredTools[index].detailLog = result.1
                
                // 安装完成后重新检查
                if result.0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.checkTool(at: index)
                    }
                }
                
                self.updateCanProceed()
            }
        }
    }
    
    private func updateCanProceed() {
        DispatchQueue.main.async {
            // 检查所有必需工具是否已安装
            self.canProceed = self.requiredTools.allSatisfy { $0.status == .installed }
        }
    }
}

struct SetupWizardView_Previews: PreviewProvider {
    static var previews: some View {
        SetupWizardView()
    }
}
