import SwiftUI

// 语言管理主界面
struct LanguageManagementView: View {
    @StateObject private var viewModel = LanguageManagementViewModel()
    @State private var selectedLanguage: ProgrammingLanguage?
    @State private var showingAddLanguage = false
    
    var body: some View {
        HStack(spacing: 0) {
            // 左侧：语言列表
            VStack(spacing: 0) {
                // 标题栏
                HStack {
                    Text(tr("Language Management"))
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.refreshAll()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                
                Divider()
                
                // 添加语言按钮
                Button(action: {
                    showingAddLanguage = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(tr("Add Language"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .padding()
                
                Divider()
                
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(viewModel.languages) { language in
                            LanguageCard(
                                language: language,
                                isSelected: selectedLanguage?.id == language.id
                            )
                            .onTapGesture {
                                selectedLanguage = language
                            }
                        }
                    }
                    .padding()
                }
            }
            .frame(width: 300)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // 右侧：语言详情
            if let language = selectedLanguage {
                LanguageDetailView(language: language, viewModel: viewModel)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(tr("Select Language"))
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingAddLanguage) {
            AddLanguageView(viewModel: viewModel)
        }
        .onAppear {
            viewModel.loadLanguages()
        }
    }
}

// 语言卡片
struct LanguageCard: View {
    let language: ProgrammingLanguage
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // 语言图标
            ZStack {
                Circle()
                    .fill(language.color.opacity(0.2))
                    .frame(width: 48, height: 48)
                
                Image(systemName: language.icon)
                    .font(.title2)
                    .foregroundColor(language.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(language.displayName)
                    .font(.headline)
                
                if let version = language.currentVersion {
                    Text("v\(version)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("未安装")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            // 状态指示器
            if language.isInstalled {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}

// 语言详情视图
struct LanguageDetailView: View {
    let language: ProgrammingLanguage
    @ObservedObject var viewModel: LanguageManagementViewModel
    
    @State private var selectedVersion: String = ""
    @State private var customVersionInput: String = ""
    @State private var isInstalling: Bool = false
    @State private var installLog: String = ""
    @State private var showSuccessAlert: Bool = false
    @State private var successMessage: String = ""
    
    // 直接从 viewModel.languages 获取最新的语言数据
    // SwiftUI 会自动响应 @Published 属性的变化
    private var currentLanguage: ProgrammingLanguage? {
        viewModel.languages.first(where: { $0.id == language.id })
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(language.color.opacity(0.2))
                            .frame(width: 64, height: 64)
                        
                        Image(systemName: language.icon)
                            .font(.system(size: 32))
                            .foregroundColor(language.color)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(language.displayName)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(language.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                
                // 当前版本信息
                VStack(alignment: .leading, spacing: 12) {
                    Text("当前全局版本")
                        .font(.headline)
                    
                    if let lang = currentLanguage, let currentVersion = lang.currentVersion {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(currentVersion)
                                    .font(.title3)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                // 显示版本来源
                                Text("(\(lang.versionSource.displayName))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.2))
                                    .cornerRadius(4)
                                
                                Button("查看详情") {
                                    viewModel.showVersionDetails(language: lang, version: currentVersion)
                                }
                                .font(.caption)
                            }
                            
                            // 显示 asdf 全局配置状态
                            if lang.versionSource == .asdf {
                                if let asdfGlobal = lang.asdfGlobalVersion, asdfGlobal == currentVersion {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                        Text("asdf 全局配置已设置")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                } else if lang.asdfGlobalVersion != currentVersion {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                            .font(.caption)
                                        Text("当前使用版本与 asdf 全局配置不一致")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            } else if lang.versionSource != .asdf && lang.asdfGlobalVersion != nil {
                                HStack {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                    Text("asdf 已配置但当前使用 \(lang.versionSource.displayName) 版本")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // 显示版本路径
                            if let path = lang.versionPath {
                                Text(path)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    } else {
                        Text("未设置全局版本")
                            .foregroundColor(.orange)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                Divider()
                
                // 已安装版本列表
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("已安装版本")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: {
                            if let lang = currentLanguage {
                                viewModel.refreshInstalledVersions(language: lang)
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    
                    if let lang = currentLanguage {
                        if lang.installedVersions.isEmpty {
                            Text("尚未安装任何版本")
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(8)
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(lang.installedVersions, id: \.self) { version in
                                    InstalledVersionRow(
                                        version: version,
                                        isCurrent: version == lang.currentVersion,
                                        onSetGlobal: { completion in
                                            // 使用 viewModel 中的最新数据
                                            if let currentLang = currentLanguage {
                                                viewModel.setGlobalVersion(language: currentLang, version: version) { success in
                                                    if success {
                                                        successMessage = "已成功将 \(currentLang.displayName) 全局版本设置为 \(version)"
                                                        showSuccessAlert = true
                                                        
                                                        // 延迟刷新完整状态，确保设置命令已完成
                                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                                            if let updatedLang = viewModel.languages.first(where: { $0.id == currentLang.id }) {
                                                                viewModel.refreshInstalledVersions(language: updatedLang)
                                                            }
                                                        }
                                                    }
                                                    completion(success)
                                                }
                                            } else {
                                                completion(false)
                                            }
                                        },
                                        onUninstall: {
                                            if let currentLang = currentLanguage {
                                                viewModel.uninstallVersion(language: currentLang, version: version)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
                
                Divider()
                
                // 安装新版本
                VStack(alignment: .leading, spacing: 12) {
                    Text("安装新版本")
                        .font(.headline)
                    
                    // 版本选择方式
                    Picker("选择方式", selection: $viewModel.versionSelectionMode) {
                        Text("从列表选择").tag(VersionSelectionMode.fromList)
                        Text("手动输入").tag(VersionSelectionMode.manual)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    if viewModel.versionSelectionMode == .fromList {
                        // 可用版本下拉列表
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("可用版本")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button("刷新列表") {
                                    if let lang = currentLanguage {
                                        viewModel.loadAvailableVersions(language: lang)
                                    }
                                }
                                .font(.caption)
                            }
                            
                            if let lang = currentLanguage {
                                if lang.availableVersions.isEmpty {
                                    HStack {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("加载版本列表...")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                } else {
                                    Picker("选择版本", selection: $selectedVersion) {
                                        Text("选择版本...").tag("")
                                        ForEach(lang.availableVersions, id: \.self) { version in
                                            Text(version).tag(version)
                                        }
                                    }
                                    .labelsHidden()
                                }
                            }
                        }
                    } else {
                        // 手动输入版本号
                        VStack(alignment: .leading, spacing: 8) {
                            Text("输入版本号")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            TextField("例如: 3.12.0", text: $customVersionInput)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Text("提示: 请输入完整的版本号，如 3.12.0 或 latest")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // 安装按钮
                    Button(action: {
                        let versionToInstall = viewModel.versionSelectionMode == .fromList ? selectedVersion : customVersionInput
                        if !versionToInstall.isEmpty {
                            installVersion(versionToInstall)
                        }
                    }) {
                        HStack {
                            if isInstalling {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("安装中...")
                            } else {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("安装版本")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canInstall ? Color.blue : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!canInstall || isInstalling)
                    
                    // 安装日志
                    if !installLog.isEmpty {
                        ScrollView {
                            Text(installLog)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 150)
                        .padding()
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
        .frame(minWidth: 500)
        .alert("操作成功", isPresented: $showSuccessAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(successMessage)
        }
        .onAppear {
            if let lang = currentLanguage {
                viewModel.loadAvailableVersions(language: lang)
            }
        }
        // SwiftUI 会自动响应 @ObservedObject 中 @Published 属性的变化
        // 不需要额外的 onChange 监听
    }
    
    private var canInstall: Bool {
        if viewModel.versionSelectionMode == .fromList {
            return !selectedVersion.isEmpty
        } else {
            return !customVersionInput.isEmpty
        }
    }
    
    private func installVersion(_ version: String) {
        guard let lang = currentLanguage else { return }
        
        isInstalling = true
        installLog = "开始安装 \(lang.displayName) \(version)...\n"
        
        viewModel.installVersion(language: lang, version: version) { success, log, tip in
            installLog += log
            if let tip = tip {
                installLog += "\n\n💡 提示: \(tip)"
            }
            isInstalling = false
            
            if success {
                successMessage = "成功安装 \(lang.displayName) \(version)！"
                showSuccessAlert = true
                
                // 延迟刷新，确保安装完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let updatedLang = viewModel.languages.first(where: { $0.id == lang.id }) {
                        viewModel.refreshInstalledVersions(language: updatedLang)
                    }
                }
                
                // 清空输入
                selectedVersion = ""
                customVersionInput = ""
            }
        }
    }
}

// 已安装版本行
struct InstalledVersionRow: View {
    let version: String
    let isCurrent: Bool
    let onSetGlobal: (@escaping (Bool) -> Void) -> Void
    let onUninstall: () -> Void
    
    @State private var showingUninstallAlert = false
    @State private var isSettingGlobal = false
    @State private var showSuccessToast = false
    
    var body: some View {
        HStack {
            Text(version)
                .font(.system(.body, design: .monospaced))
                .fontWeight(isCurrent ? .bold : .regular)
            
            if isCurrent {
                Text("(全局)")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.green)
                    .cornerRadius(4)
            }
            
            if showSuccessToast {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("已设置")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .transition(.opacity.combined(with: .scale))
            }
            
            Spacer()
            
            if !isCurrent && !showSuccessToast {
                Button(action: {
                    withAnimation {
                        isSettingGlobal = true
                    }
                    onSetGlobal { success in
                        DispatchQueue.main.async {
                            withAnimation {
                                isSettingGlobal = false
                                if success {
                                    showSuccessToast = true
                                    // 3秒后隐藏提示
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                        withAnimation {
                                            showSuccessToast = false
                                        }
                                    }
                                }
                            }
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        if isSettingGlobal {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: "globe")
                        }
                        Text(isSettingGlobal ? "设置中..." : "设为全局")
                    }
                }
                .font(.caption)
                .disabled(isSettingGlobal)
            }
            
            if !showSuccessToast {
                Button(action: {
                    showingUninstallAlert = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(isCurrent ? Color.green.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .alert("确认卸载", isPresented: $showingUninstallAlert) {
            Button("取消", role: .cancel) { }
            Button("卸载", role: .destructive) {
                onUninstall()
            }
        } message: {
            Text("确定要卸载版本 \(version) 吗？")
        }
    }
}

// 版本来源类型
enum VersionSource: Equatable {
    case asdf          // 通过 asdf 安装和管理
    case homebrew      // 通过 Homebrew 安装
    case system        // 系统自带
    case other         // 其他方式（nvm, rbenv, pyenv 等）
    case notInstalled  // 未安装
    
    var displayName: String {
        switch self {
        case .asdf: return "asdf"
        case .homebrew: return "Homebrew"
        case .system: return "系统"
        case .other: return "其他"
        case .notInstalled: return "未安装"
        }
    }
}

// 编程语言数据模型
struct ProgrammingLanguage: Identifiable, Equatable {
    let id: String
    let displayName: String
    let description: String
    let icon: String
    let color: Color
    var isInstalled: Bool
    var currentVersion: String?
    var installedVersions: [String]
    var availableVersions: [String]
    var versionSource: VersionSource = .notInstalled
    var versionPath: String?          // 当前版本的路径
    var asdfGlobalVersion: String?    // asdf 全局配置中的版本（~/.tool-versions）
    
    // 手动实现 Equatable，因为 Color 不遵循 Equatable
    static func == (lhs: ProgrammingLanguage, rhs: ProgrammingLanguage) -> Bool {
        return lhs.id == rhs.id &&
               lhs.displayName == rhs.displayName &&
               lhs.description == rhs.description &&
               lhs.icon == rhs.icon &&
               lhs.isInstalled == rhs.isInstalled &&
               lhs.currentVersion == rhs.currentVersion &&
               lhs.installedVersions == rhs.installedVersions &&
               lhs.availableVersions == rhs.availableVersions &&
               lhs.versionSource == rhs.versionSource
    }
}

enum VersionSelectionMode {
    case fromList
    case manual
}

// 视图模型
class LanguageManagementViewModel: ObservableObject {
    @Published var languages: [ProgrammingLanguage] = []
    @Published var versionSelectionMode: VersionSelectionMode = .fromList
    
    private let installers = Installers()
    private let detectors = Detectors()
    
    func loadLanguages() {
        languages = [
            ProgrammingLanguage(
                id: "nodejs",
                displayName: "Node.js",
                description: "JavaScript 运行时环境",
                icon: "terminal.fill",
                color: .green,
                isInstalled: false,
                installedVersions: [],
                availableVersions: []
            ),
            ProgrammingLanguage(
                id: "python",
                displayName: "Python",
                description: "通用编程语言，适合数据科学和 Web 开发",
                icon: "chevron.left.forwardslash.chevron.right",
                color: .blue,
                isInstalled: false,
                installedVersions: [],
                availableVersions: []
            ),
            ProgrammingLanguage(
                id: "ruby",
                displayName: "Ruby",
                description: "优雅的动态语言，Rails 框架的基础",
                icon: "diamond.fill",
                color: .red,
                isInstalled: false,
                installedVersions: [],
                availableVersions: []
            ),
            ProgrammingLanguage(
                id: "java",
                displayName: "Java",
                description: "企业级应用和 Android 开发",
                icon: "cup.and.saucer.fill",
                color: .orange,
                isInstalled: false,
                installedVersions: [],
                availableVersions: []
            ),
            ProgrammingLanguage(
                id: "golang",
                displayName: "Go",
                description: "高性能并发编程语言",
                icon: "g.circle.fill",
                color: .cyan,
                isInstalled: false,
                installedVersions: [],
                availableVersions: []
            ),
            ProgrammingLanguage(
                id: "rust",
                displayName: "Rust",
                description: "安全高效的系统编程语言",
                icon: "gearshape.fill",
                color: .brown,
                isInstalled: false,
                installedVersions: [],
                availableVersions: []
            )
        ]
        
        // 延迟刷新，避免在视图更新期间修改状态
        DispatchQueue.main.async {
            self.refreshAll()
        }
    }
    
    func refreshAll() {
        for index in languages.indices {
            refreshLanguageStatus(at: index)
        }
    }
    
    func refreshLanguageStatus(at index: Int, preserveVersion: String? = nil) {
        guard index < languages.count else { return }
        let language = languages[index]
        
        DispatchQueue.global(qos: .userInitiated).async {
            // 1. 读取 ~/.tool-versions 文件获取 asdf 全局配置
            let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
            let toolVersionsPath = "\(homeDir)/.tool-versions"
            var asdfGlobalVersion: String? = nil
            
            if let toolVersionsContent = try? String(contentsOfFile: toolVersionsPath) {
                print("📖 [DEBUG] refreshLanguageStatus 读取 ~/.tool-versions 内容:\n\(toolVersionsContent)")
                for line in toolVersionsContent.components(separatedBy: .newlines) {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
                    let components = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    if components.count >= 2 && components[0] == language.id {
                        asdfGlobalVersion = components[1]
                        print("📖 [DEBUG] 找到 \(language.id) 版本: \(asdfGlobalVersion ?? "nil")")
                        break
                    }
                }
                if asdfGlobalVersion == nil {
                    print("⚠️ [DEBUG] ~/.tool-versions 中没有找到 \(language.id) 的配置")
                }
            } else {
                print("⚠️ [DEBUG] refreshLanguageStatus 无法读取 ~/.tool-versions 文件")
            }
            
            // 2. 检查 asdf 插件是否已安装
            let asdfPluginCheck = Shell.run("asdf plugin list | grep -w '\(language.id)'")
            let asdfPluginInstalled = asdfPluginCheck.code == 0
            
            // 3. 获取 asdf 已安装的版本
            let installedResult = Shell.run("asdf list \(language.id) 2>/dev/null")
            let installedVersions = VersionManager.cleanVersionOutput(installedResult.out)
            
            // 4. 检测当前实际使用的版本和来源
            var (currentVersion, versionSource, versionPath) = self.detectCurrentVersionAndSource(
                languageId: language.id,
                asdfPluginInstalled: asdfPluginInstalled,
                asdfGlobalVersion: asdfGlobalVersion
            )
            
            // 5. 如果检测失败但文件中有全局版本配置，使用文件中的版本
            if currentVersion == nil && asdfGlobalVersion != nil && asdfPluginInstalled {
                currentVersion = asdfGlobalVersion
                versionSource = .asdf
                print("✅ [DEBUG] 从文件读取版本: \(language.id) = \(asdfGlobalVersion ?? "nil")")
            }
            
            // 6. 如果提供了 preserveVersion，且检测到的版本为空，保留原有版本
            if let preserveVer = preserveVersion, currentVersion == nil {
                currentVersion = preserveVer
                print("✅ [DEBUG] 保留原有版本: \(language.id) = \(preserveVer)")
            }
            
            // 7. 确定是否已安装（包括非 asdf 方式）
            let isInstalled = asdfPluginInstalled || 
                             installedVersions.count > 0 ||
                             (currentVersion != nil && versionSource != .notInstalled)
            
            DispatchQueue.main.async {
                // 确保索引仍然有效
                guard index < self.languages.count else { return }
                
                // 创建更新后的语言对象，确保 SwiftUI 检测到变化
                var updatedLanguage = self.languages[index]
                updatedLanguage.isInstalled = isInstalled
                
                // 只有在检测到有效版本时才更新，避免覆盖已有的设置
                if currentVersion != nil {
                    updatedLanguage.currentVersion = currentVersion
                    updatedLanguage.versionSource = versionSource
                }
                
                updatedLanguage.installedVersions = installedVersions
                updatedLanguage.versionPath = versionPath
                
                // 始终更新 asdfGlobalVersion（从文件读取的值最准确）
                if asdfGlobalVersion != nil {
                    updatedLanguage.asdfGlobalVersion = asdfGlobalVersion
                    // 如果 currentVersion 还是 nil，使用 asdfGlobalVersion
                    if updatedLanguage.currentVersion == nil {
                        updatedLanguage.currentVersion = asdfGlobalVersion
                        updatedLanguage.versionSource = .asdf
                    }
                }
                
                print("✅ [DEBUG] 刷新后状态: \(language.id) currentVersion=\(updatedLanguage.currentVersion ?? "nil"), asdfGlobalVersion=\(updatedLanguage.asdfGlobalVersion ?? "nil")")
                
                // 替换整个对象以触发视图更新
                self.languages[index] = updatedLanguage
                
                // 手动触发视图更新（关键：确保 SwiftUI 检测到数组元素的变化）
                self.objectWillChange.send()
            }
        }
    }
    
    /// 检测当前版本和来源
    private func detectCurrentVersionAndSource(
        languageId: String,
        asdfPluginInstalled: Bool,
        asdfGlobalVersion: String?
    ) -> (version: String?, source: VersionSource, path: String?) {
        // 工具名称映射
        let toolName: String = {
            switch languageId {
            case "nodejs": return "node"
            case "golang": return "go"
            default: return languageId
            }
        }()
        
        // 检查实际使用的版本和路径
        let whichResult = Shell.run("which \(toolName) 2>/dev/null")
        let versionPath = whichResult.code == 0 && !whichResult.out.isEmpty 
            ? whichResult.out.trimmingCharacters(in: .whitespacesAndNewlines)
            : nil
        
        // 获取版本号
        var currentVersion: String? = nil
        var versionSource: VersionSource = .notInstalled
        
        // 优先使用 asdfGlobalVersion（从 ~/.tool-versions 读取的）
        if let globalVer = asdfGlobalVersion, asdfPluginInstalled {
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
                currentVersion = self.getVersionFromTool(languageId: languageId, toolName: toolName)
            }
            // 检查是否系统自带
            else if path.hasPrefix("/usr/bin/") || path.hasPrefix("/usr/local/bin/") {
                versionSource = .system
                currentVersion = self.getVersionFromTool(languageId: languageId, toolName: toolName)
            }
            // 检查其他版本管理器
            else {
                versionSource = .other
                currentVersion = self.getVersionFromTool(languageId: languageId, toolName: toolName)
                
                // 检测具体的版本管理器
                if path.contains("/.nvm/") {
                    // nvm
                } else if path.contains("/.rbenv/") {
                    // rbenv
                } else if path.contains("/.pyenv/") {
                    // pyenv
                }
            }
        } else {
            // 即使找不到路径，如果 asdf 有全局配置，也算作已配置（可能 shell 未正确加载）
            if asdfPluginInstalled, let globalVer = asdfGlobalVersion {
                versionSource = .asdf
                currentVersion = globalVer
            }
        }
        
        return (currentVersion, versionSource, versionPath)
    }
    
    /// 从工具本身获取版本号
    private func getVersionFromTool(languageId: String, toolName: String) -> String? {
        let versionCommands: [String: String] = [
            "nodejs": "node --version",
            "python": "python3 --version",
            "ruby": "ruby --version",
            "java": "java -version 2>&1 | head -1",
            "golang": "go version",
            "rust": "rustc --version"
        ]
        
        guard let command = versionCommands[languageId] ?? versionCommands[toolName] else {
            return nil
        }
        
        let result = Shell.run(command)
        if result.code == 0, !result.out.isEmpty {
            // 提取版本号（通常是第一个数字版本号）
            let output = result.out
            if let match = output.range(of: #"\d+\.\d+\.\d+"#, options: .regularExpression) {
                return String(output[match])
            } else if let match = output.range(of: #"\d+\.\d+"#, options: .regularExpression) {
                return String(output[match])
            }
        }
        return nil
    }
    
    func refreshInstalledVersions(language: ProgrammingLanguage) {
        guard let index = languages.firstIndex(where: { $0.id == language.id }) else { return }
        refreshLanguageStatus(at: index)
    }
    
    func loadAvailableVersions(language: ProgrammingLanguage) {
        guard let index = languages.firstIndex(where: { $0.id == language.id }) else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Shell.run("asdf list all \(language.id) 2>/dev/null | tail -30", timeout: 15)
            let versions = VersionManager.cleanVersionOutput(result.out)
            
            DispatchQueue.main.async {
                self.languages[index].availableVersions = versions
            }
        }
    }
    
    func installVersion(language: ProgrammingLanguage, version: String, completion: @escaping (Bool, String, String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // 确保插件已添加
            let pluginResult = Shell.run("asdf plugin list | grep -w '\(language.id)' || asdf plugin add \(language.id)")
            var log = pluginResult.code == 0 ? "✅ 插件已就绪\n" : "❌ 插件添加失败\n"
            
            // 安装版本
            let installResult = Shell.run("asdf install \(language.id) \(version)")
            log += installResult.out + installResult.err
            
            let success = installResult.code == 0
            let tip = success ? "安装成功！使用 '设为全局' 按钮来启用此版本。" : "安装失败，请检查版本号是否正确。"
            
            DispatchQueue.main.async {
                completion(success, log, tip)
            }
        }
    }
    
    func setGlobalVersion(language: ProgrammingLanguage, version: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // 1. 确保 asdf 插件已添加
            let pluginCheck = Shell.run("asdf plugin list | grep -w '\(language.id)'")
            if pluginCheck.code != 0 {
                let addPluginResult = Shell.run("asdf plugin add \(language.id)")
                if addPluginResult.code != 0 {
                    DispatchQueue.main.async {
                        completion(false)
                    }
                    return
                }
            }
            
            // 2. 检测 asdf 版本，确定使用哪个命令
            let asdfVersionResult = Shell.run("asdf version")
            let useSetCommand = asdfVersionResult.out.contains("0.18") || 
                               asdfVersionResult.out.contains("0.17") || 
                               asdfVersionResult.out.contains("0.16")
            
            // 根据 asdf 版本选择正确的命令
            // asdf 0.18+ 需要使用 'asdf set -u' 来设置全局版本（-u 表示 home directory）
            let globalCommand = useSetCommand ? "asdf set -u \(language.id) \(version)" : "asdf global \(language.id) \(version)"
            print("🔧 [DEBUG] asdf 版本: \(asdfVersionResult.out.prefix(50)), 使用命令: \(globalCommand)")
            
            // 设置全局版本
            let result = Shell.run("\(globalCommand) && asdf reshim \(language.id)")
            let success = result.code == 0
            
            // 打印命令执行结果
            print("🔧 [DEBUG] 命令执行结果: code=\(result.code), out=\(result.out.prefix(100)), err=\(result.err.prefix(100))")
            
            if success {
                // 3. 更新 .zshrc 文件，确保 asdf 初始化存在
                self.ensureAsdfInZshrc()
                
                // 4. 验证文件是否真的写入了（立即读取验证）
                let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
                let toolVersionsPath = "\(homeDir)/.tool-versions"
                
                // 等待一小段时间确保文件写入完成
                Thread.sleep(forTimeInterval: 0.3)
                
                var fileVerified = false
                var fileVersion: String? = nil
                
                if let content = try? String(contentsOfFile: toolVersionsPath) {
                    print("📄 [DEBUG] ~/.tool-versions 文件内容:\n\(content)")
                    for line in content.components(separatedBy: .newlines) {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
                        let components = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                        if components.count >= 2 && components[0] == language.id {
                            fileVersion = components[1]
                            if components[1] == version {
                                fileVerified = true
                            }
                            break
                        }
                    }
                    print("📄 [DEBUG] 从文件读取: \(language.id) = \(fileVersion ?? "nil"), 匹配=\(fileVerified)")
                } else {
                    print("⚠️ [DEBUG] 无法读取 ~/.tool-versions 文件")
                }
                
                // 5. 如果命令执行成功，立即更新界面（乐观更新）
                DispatchQueue.main.async {
                    if let index = self.languages.firstIndex(where: { $0.id == language.id }) {
                        // 创建更新后的语言对象
                        var updatedLanguage = self.languages[index]
                        // 优先使用文件中的版本，如果没有则使用设置的版本
                        updatedLanguage.currentVersion = fileVersion ?? version
                        updatedLanguage.asdfGlobalVersion = fileVersion ?? version
                        updatedLanguage.versionSource = .asdf
                        
                        // 替换整个对象以触发 SwiftUI 更新
                        self.languages[index] = updatedLanguage
                        
                        // 手动触发视图更新（关键：确保 SwiftUI 检测到变化）
                        self.objectWillChange.send()
                        
                        // 打印调试信息（可以在 Xcode 控制台看到）
                        print("✅ [DEBUG] 立即更新界面: \(language.id) = \(updatedLanguage.currentVersion ?? "nil")")
                    }
                    
                    // 完成回调，告诉UI设置成功（即使文件验证失败，只要命令成功也算成功）
                    completion(true)
                }
                
                // 6. 延迟刷新完整状态（确保文件写入完成后再刷新）
                // 重要：这个刷新不应该覆盖我们立即设置的值，除非文件真的更新了
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if let index = self.languages.firstIndex(where: { $0.id == language.id }) {
                        // 刷新时保留当前的设置，避免被覆盖
                        let currentSetVersion = self.languages[index].currentVersion
                        self.refreshLanguageStatus(at: index, preserveVersion: currentSetVersion)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    print("❌ [DEBUG] asdf 设置全局版本命令执行失败: \(result.err)")
                    completion(false)
                }
            }
        }
    }
    
    /// 确保 .zshrc 文件中包含 asdf 初始化，避免重复添加
    private func ensureAsdfInZshrc() {
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
        
        // 如果有 MacEnvSwitcher 标记的块，检查是否需要更新
        if hasMacEnvSwitcherMarker, let start = startMarkerIndex, let end = endMarkerIndex {
            // 保留现有块，不需要更新（因为内容已经是最新的）
            return
        }
        
        // 如果没有 asdf 初始化，在文件末尾添加
        if !hasAsdfInit {
            // 清理文件末尾多余的换行
            content = content.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 确保文件以换行符结尾（如果没有）
            if !content.isEmpty && !content.hasSuffix("\n") {
                content += "\n"
            }
            
            // 添加 asdf 初始化块
            content += "\n" + asdfInitBlock
            
            // 写回文件
            try? content.write(toFile: zshrcPath, atomically: true, encoding: .utf8)
        } else if hasAsdfInit && !hasMacEnvSwitcherMarker {
            // 如果已有其他形式的 asdf 初始化但没有 MacEnvSwitcher 标记
            // 说明可能是用户手动添加的，我们不再添加，避免重复
            // 但为了统一管理，可以选择替换（可选，这里为了安全起见，保留原有配置）
            // 如果未来需要统一管理，可以在这里添加替换逻辑
        }
    }
    
    func uninstallVersion(language: ProgrammingLanguage, version: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Shell.run("asdf uninstall \(language.id) \(version)")
            
            if result.code == 0 {
                // 刷新状态
                if let index = self.languages.firstIndex(where: { $0.id == language.id }) {
                    self.refreshLanguageStatus(at: index)
                }
            }
        }
    }
    
    func showVersionDetails(language: ProgrammingLanguage, version: String) {
        // TODO: 显示版本详细信息
    }
}

// 添加语言视图
struct AddLanguageView: View {
    @ObservedObject var viewModel: LanguageManagementViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var availablePlugins: [AsdfPlugin] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var selectedPlugin: AsdfPlugin?
    @State private var isInstalling = false
    
    var filteredPlugins: [AsdfPlugin] {
        if searchText.isEmpty {
            return availablePlugins
        }
        return availablePlugins.filter { plugin in
            plugin.name.localizedCaseInsensitiveContains(searchText) ||
            plugin.description.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField(tr("Search languages..."), text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // 可用插件列表
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text(tr("Loading available languages..."))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredPlugins.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(searchText.isEmpty ? tr("No languages available") : tr("No matching languages"))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredPlugins) { plugin in
                                AsdfPluginCard(
                                    plugin: plugin,
                                    isSelected: selectedPlugin?.name == plugin.name,
                                    isInstalled: viewModel.languages.contains(where: { $0.id == plugin.name })
                                )
                                .onTapGesture {
                                    selectedPlugin = plugin
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                Divider()
                
                // 底部操作
                HStack {
                    Button(tr("Cancel")) {
                        dismiss()
                    }
                    
                    Spacer()
                    
                    if let plugin = selectedPlugin {
                        Button(action: {
                            addLanguage(plugin)
                        }) {
                            HStack {
                                if isInstalling {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                                Text(isInstalling ? tr("Installing...") : tr("Add Language"))
                            }
                        }
                        .disabled(isInstalling || viewModel.languages.contains(where: { $0.id == plugin.name }))
                    }
                }
                .padding()
            }
            .navigationTitle(tr("Add Language"))
        }
        .frame(minWidth: 800, idealWidth: 900, minHeight: 650, idealHeight: 700)
        .onAppear {
            loadAvailablePlugins()
        }
    }
    
    private func loadAvailablePlugins() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            // 获取所有可用的 asdf 插件
            let result = Shell.run("asdf plugin list all", timeout: 30)
            
            var plugins: [AsdfPlugin] = []
            
            if result.code == 0 && !result.out.isEmpty {
                let lines = result.out.components(separatedBy: "\n")
                
                for line in lines {
                    let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    if parts.count >= 2 {
                        let name = parts[0]
                        let url = parts[1]
                        plugins.append(AsdfPlugin(
                            name: name,
                            url: url,
                            description: self.getPluginDescription(name)
                        ))
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.availablePlugins = plugins.sorted { $0.name < $1.name }
                self.isLoading = false
            }
        }
    }
    
    
    private func getPluginDescription(_ name: String) -> String {
        // 常见语言的描述
        let descriptions: [String: String] = [
            "nodejs": "JavaScript runtime built on Chrome's V8",
            "python": "Interpreted high-level programming language",
            "ruby": "Dynamic, object-oriented programming language",
            "java": "Object-oriented programming language",
            "golang": "Statically typed, compiled programming language",
            "rust": "Systems programming language focused on safety",
            "php": "Server-side scripting language",
            "elixir": "Functional, concurrent programming language",
            "erlang": "Concurrent, fault-tolerant programming language",
            "kotlin": "Statically typed programming language for JVM",
            "scala": "Functional and object-oriented language for JVM",
            "perl": "High-level, general-purpose programming language",
            "lua": "Lightweight, embeddable scripting language",
            "r": "Statistical computing and graphics language",
            "dart": "Client-optimized language for apps",
            "crystal": "Fast, type-safe programming language",
            "nim": "Efficient, expressive programming language",
            "julia": "High-performance dynamic language for computing",
            "haskell": "Purely functional programming language",
            "ocaml": "Industrial strength functional programming",
            "clojure": "Dynamic, functional Lisp dialect for JVM",
            "racket": "General-purpose programming language (Lisp/Scheme)",
            "zig": "General-purpose programming language",
            "deno": "Secure runtime for JavaScript and TypeScript"
        ]
        
        return descriptions[name] ?? "Programming language or tool"
    }
    
    private func addLanguage(_ plugin: AsdfPlugin) {
        isInstalling = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            // 首先添加 asdf 插件
            let addResult = Shell.run("asdf plugin add \(plugin.name) || true")
            
            // 等待插件添加完成
            Thread.sleep(forTimeInterval: 1.0)
            
            // 创建新语言对象
            let newLanguage = ProgrammingLanguage(
                id: plugin.name,
                displayName: plugin.name.capitalized,
                description: plugin.description,
                icon: getIconForLanguage(plugin.name),
                color: getColorForLanguage(plugin.name),
                isInstalled: false,
                currentVersion: nil,
                installedVersions: [],
                availableVersions: []
            )
            
            DispatchQueue.main.async {
                // 添加到语言列表
                viewModel.languages.append(newLanguage)
                
                // 刷新该语言的状态
                if let index = viewModel.languages.firstIndex(where: { $0.id == plugin.name }) {
                    viewModel.refreshLanguageStatus(at: index)
                    viewModel.loadAvailableVersions(language: viewModel.languages[index])
                }
                
                isInstalling = false
                dismiss()
            }
        }
    }
    
    private func getIconForLanguage(_ name: String) -> String {
        let icons: [String: String] = [
            "nodejs": "leaf.fill",
            "python": "chevron.left.forwardslash.chevron.right",
            "ruby": "diamond.fill",
            "java": "cup.and.saucer.fill",
            "golang": "g.circle.fill",
            "rust": "gearshape.2.fill",
            "php": "chevron.left.forwardslash.chevron.right",
            "elixir": "drop.fill",
            "kotlin": "k.circle.fill",
            "scala": "s.circle.fill",
            "dart": "d.circle.fill",
            "lua": "moon.fill",
            "r": "r.circle.fill"
        ]
        
        return icons[name] ?? "terminal.fill"
    }
    
    private func getColorForLanguage(_ name: String) -> Color {
        let colors: [String: Color] = [
            "nodejs": .green,
            "python": .blue,
            "ruby": .red,
            "java": .orange,
            "golang": .cyan,
            "rust": .orange,
            "php": .purple,
            "elixir": .purple,
            "kotlin": .purple,
            "scala": .red,
            "dart": .blue,
            "lua": .blue,
            "r": .blue
        ]
        
        return colors[name] ?? .gray
    }
}

// asdf 插件模型
struct AsdfPlugin: Identifiable {
    let name: String
    let url: String
    let description: String
    
    var id: String { name }
}

// 插件卡片
struct AsdfPluginCard: View {
    let plugin: AsdfPlugin
    let isSelected: Bool
    let isInstalled: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isInstalled ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundColor(isInstalled ? .green : .secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(plugin.name.capitalized)
                    .font(.headline)
                
                Text(plugin.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if isInstalled {
                Text(tr("Installed"))
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}

struct LanguageManagementView_Previews: PreviewProvider {
    static var previews: some View {
        LanguageManagementView()
    }
}
