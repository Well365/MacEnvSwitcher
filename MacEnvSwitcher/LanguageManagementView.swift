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
                
                // 显示状态：优先显示当前版本，如果没有则显示已安装状态
                if let version = language.currentVersion {
                    Text("v\(version)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if language.isInstalled && !language.installedVersions.isEmpty {
                    // 已安装但未设置全局版本
                    Text("已安装（未设置全局）")
                        .font(.caption)
                        .foregroundColor(.blue)
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
    @State private var showSystemVersionAlert: Bool = false
    @State private var systemVersionMessage: String = ""
    
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
                                        isAsdfVersion: lang.asdfInstalledVersions.contains(version),
                                        onSetGlobal: { completion in
                                            // 使用 viewModel 中的最新数据
                                            if let currentLang = currentLanguage {
                                                // 如果是系统版本，通过设置环境变量来配置
                                                let isSystemVersion = !lang.asdfInstalledVersions.contains(version)
                                                if isSystemVersion {
                                                    viewModel.setSystemVersionAsGlobal(language: currentLang, version: version) { success, message in
                                                        if success {
                                                            successMessage = "已成功将系统版本 \(version) 设置为全局版本"
                                                            showSuccessAlert = true
                                                            
                                                            // 延迟刷新完整状态
                                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                                                if let updatedLang = viewModel.languages.first(where: { $0.id == currentLang.id }) {
                                                                    viewModel.refreshInstalledVersions(language: updatedLang)
                                                                }
                                                            }
                                                        } else {
                                                            systemVersionMessage = message ?? "设置系统版本失败"
                                                            showSystemVersionAlert = true
                                                        }
                                                        completion(success)
                                                    }
                                                    return
                                                }
                                                
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
        .alert("系统版本提示", isPresented: $showSystemVersionAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(systemVersionMessage)
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
    let isAsdfVersion: Bool
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
            
            // 显示版本来源标签
            if !isAsdfVersion {
                Text("(系统)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(3)
            }
            
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
            
            // 只有 asdf 版本才能卸载，系统版本只能设为全局
            if isAsdfVersion && !showSuccessToast {
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
    var installedVersions: [String]        // 所有已安装版本（包括 asdf 和系统）
    var asdfInstalledVersions: [String]    // 仅 asdf 安装的版本
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
               lhs.asdfInstalledVersions == rhs.asdfInstalledVersions &&
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
                asdfInstalledVersions: [],
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
                asdfInstalledVersions: [],
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
                asdfInstalledVersions: [],
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
                asdfInstalledVersions: [],
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
                asdfInstalledVersions: [],
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
                asdfInstalledVersions: [],
                availableVersions: []
            ),
            ProgrammingLanguage(
                id: "php",
                displayName: "PHP",
                description: "流行的 Web 开发语言",
                icon: "server.rack",
                color: .purple,
                isInstalled: false,
                installedVersions: [],
                asdfInstalledVersions: [],
                availableVersions: []
            ),
            ProgrammingLanguage(
                id: "scala",
                displayName: "Scala",
                description: "多范式编程语言，运行在 JVM 上",
                icon: "s.circle.fill",
                color: .red,
                isInstalled: false,
                installedVersions: [],
                asdfInstalledVersions: [],
                availableVersions: []
            ),
            ProgrammingLanguage(
                id: "kotlin",
                displayName: "Kotlin",
                description: "现代 JVM 语言，Android 开发首选",
                icon: "k.circle.fill",
                color: .orange,
                isInstalled: false,
                installedVersions: [],
                asdfInstalledVersions: [],
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
            let asdfGlobalVersion = ToolVersionsManager.readVersion(for: language.id)
            
            // 2. 检查 asdf 插件是否已安装
            let asdfPluginCheck = Shell.run("asdf plugin list | grep -w '\(language.id)'")
            let asdfPluginInstalled = asdfPluginCheck.code == 0
            
            // 3. 获取 asdf 已安装的版本
            let installedResult = Shell.run("asdf list \(language.id) 2>/dev/null")
            let asdfInstalledVersions = VersionManager.cleanVersionOutput(installedResult.out)
            
            // 检测已安装的版本（包括 asdf 和系统安装）
            var installedVersions = asdfInstalledVersions
            
            // 对于 Java，额外检测系统安装的版本
            if language.id == "java" {
                let systemJavaVersions = self.detectSystemJavaVersions()
                // 合并系统版本到已安装版本列表（去重）
                for systemVersion in systemJavaVersions {
                    if !installedVersions.contains(systemVersion) {
                        installedVersions.append(systemVersion)
                    }
                }
            }
            
            // 对于其他语言，也尝试检测系统安装的版本
            // 通过检测系统路径中的可执行文件来判断
            if installedVersions.isEmpty {
                if let systemVersion = self.detectSystemInstalledVersion(languageId: language.id) {
                    installedVersions.append(systemVersion)
                    print("🔍 [DEBUG] 检测到系统安装的 \(language.id): \(systemVersion)")
                }
            }
            
            // 4. 检测当前实际使用的版本和来源
            var (currentVersion, versionSource, versionPath) = self.detectCurrentVersionAndSource(
                languageId: language.id,
                asdfPluginInstalled: asdfPluginInstalled,
                asdfGlobalVersion: asdfGlobalVersion
            )
            
            // 5. 检查是否存在系统版本配置（在 .zshrc 等文件中）
            let hasSystemVersionConfig = ShellConfigManager.hasSystemVersionConfig(languageId: language.id)
            
            // 6. 如果存在系统版本配置，优先使用系统版本（系统版本配置会在 asdf 之后执行，优先权更高）
            if hasSystemVersionConfig {
                // 从系统版本配置中检测实际使用的版本
                if let systemVersion = ShellConfigManager.detectSystemVersion(languageId: language.id) {
                    currentVersion = systemVersion
                    versionSource = .system
                    if let systemPath = self.detectSystemVersionPath(languageId: language.id, version: systemVersion) {
                        versionPath = systemPath
                    }
                    print("✅ [DEBUG] 检测到系统版本配置: \(language.id) = \(systemVersion)")
                }
            }
            
            // 7. 如果检测失败但文件中有全局版本配置，且没有系统版本配置，使用文件中的版本
            if currentVersion == nil && asdfGlobalVersion != nil && asdfPluginInstalled && !hasSystemVersionConfig {
                currentVersion = asdfGlobalVersion
                versionSource = .asdf
                print("✅ [DEBUG] 从文件读取版本: \(language.id) = \(asdfGlobalVersion ?? "nil")")
            }
            
            // 8. 如果提供了 preserveVersion，且检测到的版本为空，保留原有版本
            if let preserveVer = preserveVersion, currentVersion == nil {
                currentVersion = preserveVer
                print("✅ [DEBUG] 保留原有版本: \(language.id) = \(preserveVer)")
            }
            
            // 9. 确定是否已安装（包括非 asdf 方式）
            // 只要有已安装版本（asdf 或系统），就认为已安装，即使没有设置全局版本
            let isInstalled = installedVersions.count > 0 || 
                             asdfPluginInstalled ||
                             (currentVersion != nil && versionSource != .notInstalled)
            
            print("📊 [DEBUG] 安装状态判断: \(language.id) - isInstalled=\(isInstalled), installedVersions.count=\(installedVersions.count), asdfPluginInstalled=\(asdfPluginInstalled)")
            
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
                // 保存 asdf 安装的版本（用于区分显示）
                updatedLanguage.asdfInstalledVersions = asdfInstalledVersions
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
            // 检查是否系统 Java（macOS 特有）
            else if languageId == "java" && (path.contains("/Library/Java/JavaVirtualMachines/") || path.contains("/usr/libexec/java_home")) {
                versionSource = .system
                // 对于 Java，使用更精确的检测方法
                currentVersion = self.detectSystemJavaVersion()
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
    
    /// 检测系统安装的版本（非 asdf）
    private func detectSystemInstalledVersion(languageId: String) -> String? {
        let toolName: String = {
            switch languageId {
            case "nodejs": return "node"
            case "golang": return "go"
            default: return languageId
            }
        }()
        
        // 检查可执行文件是否存在（排除 asdf shims）
        let whichResult = Shell.run("which \(toolName) 2>/dev/null")
        guard whichResult.code == 0, !whichResult.out.isEmpty else {
            return nil
        }
        
        let executablePath = whichResult.out.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 如果是 asdf shim，不算系统安装
        if executablePath.contains("/.asdf/shims/") {
            return nil
        }
        
        // 使用 getVersionFromTool 获取版本
        return getVersionFromTool(languageId: languageId, toolName: toolName)
    }
    
    /// 从工具本身获取版本号
    private func getVersionFromTool(languageId: String, toolName: String) -> String? {
        let versionCommands: [String: String] = [
            "nodejs": "node --version",
            "python": "python3 --version",
            "ruby": "ruby --version",
            "java": "java -version 2>&1 | head -1",
            "golang": "go version",
            "rust": "rustc --version",
            "php": "php --version",
            "scala": "scala -version 2>&1",
            "kotlin": "kotlin -version 2>&1"
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
    
    /// 检测当前系统 Java 版本（更精确的方法）
    private func detectSystemJavaVersion() -> String? {
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
                let version = String(output[match]).replacingOccurrences(of: "\"", with: "")
                return version
            } else if let match = output.range(of: #"(\d+\.\d+\.\d+)"#, options: .regularExpression) {
                return String(output[match])
            }
        }
        
        // 方法3: 从 JAVA_HOME 路径提取
        let javaHome = Shell.run("echo $JAVA_HOME")
        if !javaHome.out.isEmpty {
            let path = javaHome.out.trimmingCharacters(in: .whitespacesAndNewlines)
            if let match = path.range(of: #"jdk[_-]?(\d+\.\d+\.\d+)"#, options: .regularExpression) {
                let version = String(path[match]).replacingOccurrences(of: "jdk", with: "").replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "_", with: "")
                return version
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
        
        // 1. 立即显示预置版本（提升用户体验）
        let predefinedVersions = SoftConfig.getPredefinedVersions(for: language.id)
        DispatchQueue.main.async {
            // 确保索引仍然有效
            guard index < self.languages.count else { return }
            
            self.languages[index].availableVersions = predefinedVersions
            // 触发视图更新
            self.objectWillChange.send()
            
            print("📋 [DEBUG] 立即显示预置版本: \(language.id), 共 \(predefinedVersions.count) 个版本")
        }
        
        // 2. 后台加载完整版本列表
        DispatchQueue.global(qos: .userInitiated).async {
            // 对于 Java，使用更高效的命令，只获取最近的版本
            let command: String
            let limit: Int
            let timeout: TimeInterval
            
            if language.id == "java" {
                // Java 版本列表非常长，使用 head 只获取最新的版本，避免遍历整个列表
                // 先尝试获取已安装的版本，然后获取最新的可用版本
                command = "asdf list all \(language.id) 2>/dev/null | grep -E '^(temurin|adopt|zulu|corretto|openjdk)' | head -50"
                limit = 50
                timeout = 8  // 缩短超时时间
            } else {
                command = "asdf list all \(language.id) 2>/dev/null | tail -50"
                limit = 50
                timeout = 12
            }
            
            let result = Shell.run(command, timeout: timeout)
            var loadedVersions = VersionManager.cleanVersionOutput(result.out)
            
            // 如果命令超时或失败，使用备用方法（仅获取最后几个版本）
            if loadedVersions.isEmpty || result.code != 0 {
                print("⚠️ [DEBUG] 加载版本列表超时或失败，使用备用方法")
                let fallbackCommand = "asdf list all \(language.id) 2>/dev/null | tail -20"
                let fallbackResult = Shell.run(fallbackCommand, timeout: 5)
                loadedVersions = VersionManager.cleanVersionOutput(fallbackResult.out)
            }
            
            // 限制加载的版本数量，避免列表过长
            if loadedVersions.count > limit {
                loadedVersions = Array(loadedVersions.prefix(limit))
            }
            
            // 3. 合并预置版本和加载的版本，去重
            // 使用 Set 来快速去重，但保持预置版本的顺序
            var versionSet = Set<String>()
            var mergedVersions: [String] = []
            
            // 先添加预置版本（保持原有顺序，这些版本通常是经过筛选的稳定版本）
            for version in predefinedVersions {
                if !versionSet.contains(version) {
                    versionSet.insert(version)
                    mergedVersions.append(version)
                }
            }
            
            // 然后添加从服务器加载的版本（排除已存在的）
            var loadedVersionsToAdd: [String] = []
            for version in loadedVersions {
                if !versionSet.contains(version) {
                    versionSet.insert(version)
                    loadedVersionsToAdd.append(version)
                }
            }
            
            // 对加载的版本进行排序
            loadedVersionsToAdd.sort { (v1, v2) -> Bool in
                return self.compareVersions(v1, v2) > 0
            }
            
            // 将排序后的加载版本追加到预置版本后面
            mergedVersions.append(contentsOf: loadedVersionsToAdd)
            
            // 4. 合并完成后，在主线程更新界面并强制刷新
            DispatchQueue.main.async {
                // 确保索引仍然有效
                guard index < self.languages.count else { return }
                
                // 更新版本列表
                self.languages[index].availableVersions = mergedVersions
                
                // 强制触发 SwiftUI 视图更新
                self.objectWillChange.send()
                
                print("✅ [DEBUG] 合并版本列表完成并已刷新: \(language.id), 预置 \(predefinedVersions.count) 个, 加载 \(loadedVersions.count) 个, 合并后共 \(mergedVersions.count) 个版本")
            }
        }
    }
    
    /// 比较两个版本号（用于排序）
    /// 返回: > 0 表示 v1 > v2, < 0 表示 v1 < v2, = 0 表示 v1 == v2
    private func compareVersions(_ v1: String, _ v2: String) -> Int {
        // 处理特殊版本标识
        if v1 == "latest" || v1 == "stable" { return 1 }
        if v2 == "latest" || v2 == "stable" { return -1 }
        if v1 == "system" { return -1 }
        if v2 == "system" { return 1 }
        
        // 提取版本号部分（去掉前缀如 temurin-、openjdk- 等）
        let cleanV1 = cleanVersionString(v1)
        let cleanV2 = cleanVersionString(v2)
        
        let parts1 = cleanV1.components(separatedBy: ".").compactMap { Int($0.components(separatedBy: "+").first ?? $0) }
        let parts2 = cleanV2.components(separatedBy: ".").compactMap { Int($0.components(separatedBy: "+").first ?? $0) }
        
        // 比较每个部分
        let maxCount = max(parts1.count, parts2.count)
        for i in 0..<maxCount {
            let p1 = i < parts1.count ? parts1[i] : 0
            let p2 = i < parts2.count ? parts2[i] : 0
            
            if p1 > p2 { return 1 }
            if p1 < p2 { return -1 }
        }
        
        return 0
    }
    
    /// 清理版本字符串，提取版本号部分
    private func cleanVersionString(_ version: String) -> String {
        // 移除常见的前缀
        var cleaned = version
        let prefixes = ["temurin-", "adoptopenjdk-", "adopt-", "zulu-", "corretto-", "openjdk-", "jdk-"]
        for prefix in prefixes {
            if cleaned.hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count))
                break
            }
        }
        return cleaned
    }
    
    /// 检测系统安装的 Java 版本（macOS）
    private func detectSystemJavaVersions() -> [String] {
        var systemVersions: [String] = []
        
        // 方法1: 检查 /Library/Java/JavaVirtualMachines/ 目录（最可靠的方法）
        let jvmPath = "/Library/Java/JavaVirtualMachines"
        if let jvmContents = try? FileManager.default.contentsOfDirectory(atPath: jvmPath) {
            for jvmName in jvmContents {
                // 解析 JDK 目录名，如 "jdk-11.0.21.jdk"、"temurin-17.0.9+10.jdk"、"zulu-11.jdk"
                let name = (jvmName as NSString).deletingPathExtension
                
                // 尝试提取版本号 - 多种格式
                var extractedVersion: String? = nil
                
                // 格式1: jdk-11.0.21 或 jdk-17
                if let match = name.range(of: #"jdk[_-](\d+(?:\.\d+(?:\.\d+)?)?)"#, options: .regularExpression) {
                    let matched = String(name[match])
                    extractedVersion = matched.replacingOccurrences(of: "jdk", with: "")
                        .replacingOccurrences(of: "-", with: "")
                        .replacingOccurrences(of: "_", with: "")
                }
                // 格式2: temurin-17.0.9+10
                else if let match = name.range(of: #"temurin[_-](\d+(?:\.\d+(?:\.\d+)?)?)"#, options: .regularExpression) {
                    let matched = String(name[match])
                    extractedVersion = matched.replacingOccurrences(of: "temurin", with: "")
                        .replacingOccurrences(of: "-", with: "")
                        .replacingOccurrences(of: "_", with: "")
                        .components(separatedBy: "+").first // 移除构建号
                }
                // 格式3: zulu-11 或 zulu-17.0.9
                else if let match = name.range(of: #"(zulu|adopt|corretto|openjdk)[_-](\d+(?:\.\d+(?:\.\d+)?)?)"#, options: .regularExpression) {
                    let matched = String(name[match])
                    let components = matched.components(separatedBy: "-")
                    if components.count >= 2 {
                        extractedVersion = components.last?.components(separatedBy: "+").first
                    }
                }
                // 格式4: 纯数字版本号
                else if let match = name.range(of: #"(\d+\.\d+\.\d+)"#, options: .regularExpression) {
                    extractedVersion = String(name[match])
                }
                // 格式5: 主版本号（如 11, 17）
                else if let match = name.range(of: #"(\d+)"#, options: .regularExpression) {
                    let matched = String(name[match])
                    // 只接受合理的版本号（8-25之间）
                    if let majorVersion = Int(matched), majorVersion >= 8 && majorVersion <= 25 {
                        extractedVersion = matched
                    }
                }
                
                if let version = extractedVersion, !version.isEmpty {
                    // 标准化版本格式（确保至少是 x.y 格式）
                    let components = version.components(separatedBy: ".")
                    let normalizedVersion: String
                    if components.count == 1 {
                        // 只有主版本号，添加 .0
                        normalizedVersion = "\(components[0]).0"
                    } else {
                        normalizedVersion = version
                    }
                    
                    if !systemVersions.contains(normalizedVersion) && !systemVersions.contains(version) {
                        systemVersions.append(normalizedVersion)
                    }
                }
            }
        }
        
        // 方法2: 使用 /usr/libexec/java_home -V 获取所有系统 Java 版本（作为补充）
        let javaHomeResult = Shell.run("/usr/libexec/java_home -V 2>&1")
        if javaHomeResult.code == 0 {
            let lines = javaHomeResult.out.components(separatedBy: .newlines)
            for line in lines {
                // 解析格式如: "Java SE 17.0.9" 或 "OpenJDK 11.0.21" 或路径中的版本号
                if let match = line.range(of: #"\d+\.\d+\.\d+"#, options: .regularExpression) {
                    let version = String(line[match])
                    let components = version.components(separatedBy: ".")
                    let normalizedVersion = components.count >= 2 ? "\(components[0]).\(components[1])" : version
                    
                    if !systemVersions.contains(normalizedVersion) && !systemVersions.contains(version) {
                        systemVersions.append(normalizedVersion)
                    }
                } else if let match = line.range(of: #"(\d+\.\d+)"#, options: .regularExpression) {
                    let version = String(line[match])
                    if !systemVersions.contains(version) {
                        systemVersions.append(version)
                    }
                }
            }
        }
        
        // 方法3: 检查 Homebrew 安装的 Java
        let brewJavaResult = Shell.run("brew list --cask --versions 2>/dev/null | grep -E '(java|openjdk|temurin)'")
        if brewJavaResult.code == 0 {
            let lines = brewJavaResult.out.components(separatedBy: .newlines)
            for line in lines {
                if let match = line.range(of: #"\d+\.\d+\.\d+"#, options: .regularExpression) {
                    let version = String(line[match])
                    let components = version.components(separatedBy: ".")
                    let normalizedVersion = components.count >= 2 ? "\(components[0]).\(components[1])" : version
                    
                    if !systemVersions.contains(normalizedVersion) && !systemVersions.contains(version) {
                        systemVersions.append(normalizedVersion)
                    }
                }
            }
        }
        
        // 排序：按版本号降序排列（最新在前）
        systemVersions.sort { (v1, v2) -> Bool in
            let parts1 = v1.components(separatedBy: ".").compactMap { Int($0) }
            let parts2 = v2.components(separatedBy: ".").compactMap { Int($0) }
            
            for i in 0..<max(parts1.count, parts2.count) {
                let p1 = i < parts1.count ? parts1[i] : 0
                let p2 = i < parts2.count ? parts2[i] : 0
                if p1 != p2 {
                    return p1 > p2
                }
            }
            return false
        }
        
        print("🔍 [DEBUG] 检测到系统 Java 版本: \(systemVersions)")
        return systemVersions
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
                // 3. 删除或注释 shell 配置文件中该语言的系统版本配置（避免系统配置和 asdf 配置冲突）
                ShellConfigManager.removeSystemVersionConfigFromAllFiles(languageId: language.id)
                
                // 4. 更新 .zshrc 文件，确保 asdf 初始化存在
                ShellConfigManager.ensureAsdfInZshrc()
                
                // 5. 验证文件是否真的写入了（立即读取验证）
                Thread.sleep(forTimeInterval: 0.3)
                
                let fileVersion = ToolVersionsManager.readVersion(for: language.id)
                let fileVerified = fileVersion == version
                
                print("📄 [DEBUG] 从文件读取: \(language.id) = \(fileVersion ?? "nil"), 匹配=\(fileVerified)")
                
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
    /// 设置系统版本为全局版本（通过环境变量）
    func setSystemVersionAsGlobal(language: ProgrammingLanguage, version: String, completion: @escaping (Bool, String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // 1. 检测系统版本的安装路径
            guard let installPath = self.detectSystemVersionPath(languageId: language.id, version: version) else {
                DispatchQueue.main.async {
                    completion(false, "无法找到系统版本 \(version) 的安装路径")
                }
                return
            }
            
            print("🔍 [DEBUG] 检测到系统版本路径: \(language.id) \(version) -> \(installPath)")
            
            // 2. 获取语言对应的环境变量配置
            guard let envConfig = self.getSystemVersionEnvConfig(languageId: language.id, installPath: installPath, version: version) else {
                DispatchQueue.main.async {
                    completion(false, "不支持的语言类型: \(language.id)")
                }
                return
            }
            
            // 3. 删除 .tool-versions 中该语言的配置（避免 asdf 配置和系统配置冲突）
            ToolVersionsManager.removeVersion(for: language.id)
            
            // 4. 写入所有 shell 配置文件（.zshrc, .bashrc, .bash_profile, .zprofile 等）
            let success = ShellConfigManager.setSystemVersionConfigInAllFiles(envConfig: envConfig, languageId: language.id, installPath: installPath)
            
            if success {
                // 4. 更新界面
                DispatchQueue.main.async {
                    if let index = self.languages.firstIndex(where: { $0.id == language.id }) {
                        var updatedLanguage = self.languages[index]
                        updatedLanguage.currentVersion = version
                        updatedLanguage.versionSource = .system
                        updatedLanguage.versionPath = installPath
                        
                        self.languages[index] = updatedLanguage
                        self.objectWillChange.send()
                        
                        print("✅ [DEBUG] 系统版本设置成功: \(language.id) = \(version), 路径: \(installPath)")
                    }
                    completion(true, nil)
                }
            } else {
                DispatchQueue.main.async {
                    completion(false, "写入 shell 配置文件失败")
                }
            }
        }
    }
    
    /// 检测系统版本的安装路径
    private func detectSystemVersionPath(languageId: String, version: String) -> String? {
        // 对于不同语言，使用不同的检测策略
        switch languageId {
        case "java":
            // Java 特殊处理：直接使用 java_home 工具获取指定版本的路径
            // 不使用 which java，因为它可能返回 asdf shim 或其他版本管理器的路径
            
            // 方法1: 尝试完整版本号（如 11.0.21）
            var javaHomeResult = Shell.run("/usr/libexec/java_home -v \(version) 2>/dev/null")
            if javaHomeResult.code == 0, !javaHomeResult.out.isEmpty {
                let javaHome = javaHomeResult.out.trimmingCharacters(in: .whitespacesAndNewlines)
                print("🔍 [DEBUG] 通过完整版本号找到 Java 路径: \(version) -> \(javaHome)")
                return javaHome
            }
            
            // 方法2: 尝试去掉最后的小版本号（如 11.0）
            let versionParts = version.components(separatedBy: ".")
            if versionParts.count >= 2 {
                let majorMinor = "\(versionParts[0]).\(versionParts[1])"
                javaHomeResult = Shell.run("/usr/libexec/java_home -v \(majorMinor) 2>/dev/null")
                if javaHomeResult.code == 0, !javaHomeResult.out.isEmpty {
                    let javaHome = javaHomeResult.out.trimmingCharacters(in: .whitespacesAndNewlines)
                    print("🔍 [DEBUG] 通过主次版本号找到 Java 路径: \(majorMinor) -> \(javaHome)")
                    return javaHome
                }
            }
            
            // 方法3: 尝试主版本号（如 11）
            if let majorVersion = versionParts.first {
                javaHomeResult = Shell.run("/usr/libexec/java_home -v \(majorVersion) 2>/dev/null")
                if javaHomeResult.code == 0, !javaHomeResult.out.isEmpty {
                    let javaHome = javaHomeResult.out.trimmingCharacters(in: .whitespacesAndNewlines)
                    print("🔍 [DEBUG] 通过主版本号找到 Java 路径: \(majorVersion) -> \(javaHome)")
                    return javaHome
                }
            }
            
            print("⚠️ [DEBUG] 无法找到 Java \(version) 的安装路径")
            return nil
            
        default:
            // 对于其他语言，使用 which 命令找到可执行文件路径
            let toolName: String = {
                switch languageId {
                case "nodejs": return "node"
                case "golang": return "go"
                default: return languageId
                }
            }()
            
            let whichResult = Shell.run("which \(toolName)")
            guard whichResult.code == 0, !whichResult.out.isEmpty else {
                return nil
            }
            
            let executablePath = whichResult.out.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 跳过 asdf shims，如果是 asdf shim 则需要从其他方式检测
            if executablePath.contains("/.asdf/shims/") {
                print("⚠️ [DEBUG] which \(toolName) 返回 asdf shim，可能需要手动指定系统版本路径")
                // 对于系统版本，不应该通过 asdf shim，返回 nil 让用户知道
                return nil
            }
            
            switch languageId {
            case "golang":
                // Go 安装路径通常是可执行文件的父目录的父目录
                if executablePath.hasSuffix("/bin/go") {
                    let path = executablePath as NSString
                    let binPath = path.deletingLastPathComponent
                    let goRoot = (binPath as NSString).deletingLastPathComponent
                    return goRoot
                }
                return nil
                
            case "python":
                // Python 安装路径是可执行文件的父目录的父目录
                if executablePath.contains("/bin/python") {
                    let path = executablePath as NSString
                    let binPath = path.deletingLastPathComponent
                    let pythonPath = (binPath as NSString).deletingLastPathComponent
                    return pythonPath
                }
                return nil
                
            case "rust":
                // Rust 安装路径通常是 ~/.rustup 或 /usr/local
                if executablePath.contains("/.cargo/bin/") {
                    let path = executablePath as NSString
                    let binPath = path.deletingLastPathComponent
                    let rustPath = (binPath as NSString).deletingLastPathComponent
                    return rustPath
                }
                return nil
                
            case "ruby":
                // Ruby 系统安装路径
                if executablePath.contains("/usr/bin/ruby") || executablePath.contains("/usr/local/bin/ruby") {
                    return "/usr"
                } else if executablePath.contains("/opt/homebrew") {
                    let path = executablePath as NSString
                    let binPath = path.deletingLastPathComponent
                    let rubyPath = (binPath as NSString).deletingLastPathComponent
                    return rubyPath
                }
                return nil
                
            case "php":
                // PHP 安装路径
                if executablePath.contains("/usr/bin/php") {
                    return "/usr"
                } else if executablePath.contains("/opt/homebrew") {
                    let path = executablePath as NSString
                    let binPath = path.deletingLastPathComponent
                    let phpPath = (binPath as NSString).deletingLastPathComponent
                    return phpPath
                }
                return nil
                
            case "nodejs":
                // Node.js 系统安装路径
                if executablePath.contains("/usr/local/bin/node") {
                    return "/usr/local"
                } else if executablePath.contains("/opt/homebrew") {
                    let path = executablePath as NSString
                    let binPath = path.deletingLastPathComponent
                    let nodePath = (binPath as NSString).deletingLastPathComponent
                    return nodePath
                }
                return nil
                
            default:
                // 默认返回可执行文件的 bin 目录的父目录
                let path = executablePath as NSString
                let binPath = path.deletingLastPathComponent
                return (binPath as NSString).deletingLastPathComponent
            }
        }
    }
    
    /// 获取系统版本的环境变量配置
    private func getSystemVersionEnvConfig(languageId: String, installPath: String, version: String) -> [String: String]? {
        var envVars: [String: String] = [:]
        
        switch languageId {
        case "java":
            envVars["JAVA_HOME"] = installPath
            // Java 需要确保 JAVA_HOME/bin 在 PATH 最前面，并移除其他 Java 路径
            envVars["PATH"] = "$JAVA_HOME/bin:$PATH"
            
        case "golang":
            envVars["GOROOT"] = installPath
            envVars["GOPATH"] = "$HOME/go"
            envVars["PATH"] = "$GOROOT/bin:$GOPATH/bin:$PATH"
            
        case "python":
            envVars["PYTHON_HOME"] = installPath
            envVars["PATH"] = "$PYTHON_HOME/bin:$PATH"
            
        case "rust":
            envVars["CARGO_HOME"] = "$HOME/.cargo"
            envVars["RUSTUP_HOME"] = "$HOME/.rustup"
            envVars["PATH"] = "$CARGO_HOME/bin:$PATH"
            
        case "ruby":
            envVars["RUBY_HOME"] = installPath
            envVars["PATH"] = "$RUBY_HOME/bin:$PATH"
            
        case "php":
            envVars["PHP_HOME"] = installPath
            envVars["PATH"] = "$PHP_HOME/bin:$PATH"
            
        case "nodejs":
            envVars["NODE_HOME"] = installPath
            envVars["PATH"] = "$NODE_HOME/bin:$PATH"
            
        case "typescript":
            // TypeScript 通常通过 npm 安装，但如果是系统安装，使用类似的配置
            envVars["TYPESCRIPT_HOME"] = installPath
            envVars["PATH"] = "$TYPESCRIPT_HOME/bin:$PATH"
            
        case "kotlin":
            // Kotlin 通常通过 Java 运行，需要设置 KOTLIN_HOME
            envVars["KOTLIN_HOME"] = installPath
            envVars["PATH"] = "$KOTLIN_HOME/bin:$PATH"
            
        default:
            return nil
        }
        
        return envVars
    }
    
    /// 在所有 shell 配置文件中设置系统版本的环境变量
    private func setSystemVersionInAllShellConfigs(envConfig: [String: String], languageId: String, installPath: String) -> Bool {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let shellConfigFiles = [
            "\(homeDir)/.zshrc",
            "\(homeDir)/.bashrc",
            "\(homeDir)/.bash_profile",
            "\(homeDir)/.zprofile",
            "\(homeDir)/.profile"
        ]
        
        var successCount = 0
        for configPath in shellConfigFiles {
            if self.setSystemVersionInShellConfig(configPath: configPath, envConfig: envConfig, languageId: languageId, installPath: installPath) {
                successCount += 1
            }
        }
        
        // 至少成功写入一个配置文件就算成功
        return successCount > 0
    }
    
    /// 在指定的 shell 配置文件中设置系统版本的环境变量
    private func setSystemVersionInShellConfig(configPath: String, envConfig: [String: String], languageId: String, installPath: String) -> Bool {
        let fileManager = FileManager.default
        
        // 如果文件不存在，创建它
        if !fileManager.fileExists(atPath: configPath) {
            try? "".write(toFile: configPath, atomically: true, encoding: .utf8)
        }
        
        // 读取文件内容
        guard var content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return false
        }
        
        // 对于非 .zshrc 文件，不需要确保 asdf 初始化（只在 .zshrc 中处理）
        let isZshrc = configPath.hasSuffix(".zshrc")
        
        // 1. 移除该语言的所有旧配置块（避免重复）
        let markerStart = "# MacEnvSwitcher: System \(languageId) version configuration"
        let markerEnd = "# End MacEnvSwitcher system \(languageId) configuration"
        
        while let startRange = content.range(of: markerStart),
              let endRange = content.range(of: markerEnd, range: startRange.upperBound..<content.endIndex) {
            content.removeSubrange(startRange.lowerBound..<endRange.upperBound)
        }
        
        // 2. 构建环境变量配置块
        var envLines: [String] = []
        var pathToPrepend: String? = nil
        
        for (key, value) in envConfig {
            if key == "PATH" {
                // PATH 特殊处理：提取需要前置的路径
                pathToPrepend = value.replacingOccurrences(of: "$PATH", with: "").trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            } else {
                envLines.append("export \(key)=\"\(value)\"")
            }
        }
        
        // 3. 如果有 PATH 需要处理，添加 PATH 设置（确保在最前面）
        if let pathPrefix = pathToPrepend {
            // 移除 PATH 中可能存在的旧版本路径，然后将新路径放在最前面
            envLines.append("")
            envLines.append("# 确保系统 \(languageId) 版本的 bin 目录在 PATH 最前面")
            
            // 根据语言类型，清理可能冲突的路径
            var pathsToRemove: [String] = []
            switch languageId {
            case "java":
                // 移除其他 Java 相关的路径（包括所有可能的 Java 安装路径）
                // 需要移除所有包含 Java 相关路径的项
                pathsToRemove = [
                    "/Library/Java/JavaVirtualMachines",
                    "/System/Library/Frameworks/JavaVM.framework",
                    "/opt/homebrew/Cellar/openjdk",
                    "/opt/homebrew/opt/openjdk",
                    "/usr/local/opt/openjdk",
                    "/usr/local/Cellar/openjdk",
                    "jdk",
                    "JavaVirtualMachines",
                    "openjdk"
                ]
                // 特别注意：需要移除 asdf 的 java shim，让系统版本优先
                // 但是 asdf shims 在 asdf 初始化时已经添加到 PATH，所以我们需要在 PATH 设置时排除它
            case "golang", "go":
                pathsToRemove = ["/usr/local/go", "/opt/homebrew/opt/go", "/opt/homebrew/bin/go"]
            case "python":
                pathsToRemove = ["/usr/local/opt/python", "/opt/homebrew/opt/python", "/Library/Frameworks/Python.framework"]
            case "rust":
                // Rust 的路径通常在用户目录，需要特殊处理
                pathsToRemove = []
            case "ruby":
                pathsToRemove = ["/usr/local/opt/ruby", "/opt/homebrew/opt/ruby", "/System/Library/Frameworks/Ruby.framework"]
            case "php":
                pathsToRemove = ["/usr/local/opt/php", "/opt/homebrew/opt/php"]
            case "nodejs":
                pathsToRemove = ["/usr/local/opt/node", "/opt/homebrew/opt/node", "/usr/local/lib/node_modules"]
            default:
                break
            }
            
            // 构建 PATH 清理和设置命令
            // 关键：系统版本的路径必须在最前面，在所有其他路径（包括 asdf shims）之前
            if languageId == "java" {
                // Java 特殊处理：需要移除所有 Java 相关路径，包括 asdf shims 和 Homebrew 安装的 Java
                envLines.append("# Java 特殊处理：移除所有其他 Java 路径，确保当前 JAVA_HOME/bin 在最前面")
                envLines.append("# 移除 asdf java shim、Homebrew 安装的 Java 和其他版本管理器的路径，让系统 Java 版本优先")
                // 精确清理：移除所有 Java 相关的安装路径
                envLines.append("export PATH=\"$JAVA_HOME/bin:\"$(echo $PATH | tr ':' '\\n' | grep -v \"\\.asdf/shims\" | grep -v \"/Library/Java/JavaVirtualMachines\" | grep -v \"/System/Library/Frameworks/JavaVM.framework\" | grep -v \"/opt/homebrew/Cellar/openjdk\" | grep -v \"/opt/homebrew/opt/openjdk\" | grep -v \"/opt/homebrew/bin/java\" | grep -v \"/usr/local/opt/openjdk\" | grep -v \"/usr/local/Cellar/openjdk\" | grep -v \"/usr/local/bin/java\" | grep -vE \"(JavaVirtualMachines|JavaVM|jdk-|jdk1|openjdk)\" | grep -v \"$JAVA_HOME/bin\" | tr '\\n' ':' | sed 's/:$//' | sed 's/^://')")
            } else if !pathsToRemove.isEmpty {
                // 其他语言：移除冲突路径，并将新路径放在最前面
                // 规则：1) 系统版本路径在最前面 2) 移除 asdf shims 3) 移除其他版本路径
                let removePattern = pathsToRemove.joined(separator: "\\|")
                envLines.append("# 移除其他 \(languageId) 版本路径和 asdf shims，确保系统版本优先")
                envLines.append("export PATH=\"\(pathPrefix):\"$(echo $PATH | tr ':' '\\n' | grep -vE \"\(removePattern)\" | grep -v \"\\.asdf/shims\" | grep -v \"^\(pathPrefix)$\" | tr '\\n' ':' | sed 's/:$//' | sed 's/^://')")
            } else {
                // 通用处理：去重并前置新路径，移除 asdf shims（让系统版本优先）
                // 适用于没有特定路径需要移除的语言（如 Rust）
                envLines.append("# 移除 asdf shims，确保系统 \(languageId) 版本优先")
                envLines.append("export PATH=\"\(pathPrefix):\"$(echo $PATH | tr ':' '\\n' | grep -v \"\\.asdf/shims\" | awk '!seen[$0]++' | grep -v \"^\(pathPrefix)$\" | tr '\\n' ':' | sed 's/:$//' | sed 's/^://')")
            }
        }
        
        let configBlock = """
# MacEnvSwitcher: System \(languageId) version configuration
\(envLines.joined(separator: "\n"))
# End MacEnvSwitcher system \(languageId) configuration

"""
        
        // 4. 查找插入位置（对于 .zshrc，需要在 asdf 初始化之后）
        var updatedContent = content
        
        if isZshrc {
            // 对于 .zshrc，先确保 asdf 初始化存在
            ShellConfigManager.ensureAsdfInZshrc()
            
            // 重新读取文件（因为 ensureAsdfInZshrc 可能修改了文件）
            guard let reloadedContent = try? String(contentsOfFile: configPath, encoding: .utf8) else {
                return false
            }
            updatedContent = reloadedContent
            
            // 移除该语言的旧配置（如果 ensureAsdfInZshrc 后还有残留）
            while let startRange = updatedContent.range(of: markerStart),
                  let endRange = updatedContent.range(of: markerEnd, range: startRange.upperBound..<updatedContent.endIndex) {
                updatedContent.removeSubrange(startRange.lowerBound..<endRange.upperBound)
            }
            
            // 查找插入位置：在 asdf 初始化块之后（重要：系统版本配置要在 asdf 之后，这样可以覆盖 asdf 的设置）
            let asdfEndMarker = "# End MacEnvSwitcher asdf initialization"
            if let asdfEndRange = updatedContent.range(of: asdfEndMarker) {
                // 在 asdf 初始化之后插入（这样系统版本可以覆盖 asdf shims）
                let insertIndex = updatedContent.index(asdfEndRange.upperBound, offsetBy: 0)
                // 确保有换行符
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
            // 移除旧配置
            while let startRange = updatedContent.range(of: markerStart),
                  let endRange = updatedContent.range(of: markerEnd, range: startRange.upperBound..<updatedContent.endIndex) {
                updatedContent.removeSubrange(startRange.lowerBound..<endRange.upperBound)
            }
            
            // 追加新配置
            if !updatedContent.hasSuffix("\n") {
                updatedContent += "\n"
            }
            updatedContent += configBlock
        }
        
        // 5. 写入文件
        do {
            try updatedContent.write(toFile: configPath, atomically: true, encoding: .utf8)
            let fileName = (configPath as NSString).lastPathComponent
            print("✅ [DEBUG] 已写入 \(fileName): \(languageId) 环境变量配置")
            return true
        } catch {
            print("❌ [DEBUG] 写入 \(configPath) 失败: \(error)")
            return false
        }
    }
    
    /// 从 .tool-versions 文件中删除指定语言的配置
    private func removeLanguageFromToolVersions(languageId: String) {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let toolVersionsPath = "\(homeDir)/.tool-versions"
        let fileManager = FileManager.default
        
        // 如果文件不存在，直接返回
        guard fileManager.fileExists(atPath: toolVersionsPath),
              var content = try? String(contentsOfFile: toolVersionsPath, encoding: .utf8) else {
            print("📝 [DEBUG] ~/.tool-versions 文件不存在或无法读取，跳过删除操作")
            return
        }
        
        var lines = content.components(separatedBy: .newlines)
        var modified = false
        
        // 删除包含该语言配置的行
        lines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            // 如果是注释或空行，保留
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                return true
            }
            // 检查是否是目标语言的配置行
            let components = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if components.count >= 2 && components[0] == languageId {
                modified = true
                print("🗑️ [DEBUG] 从 ~/.tool-versions 中删除: \(line)")
                return false  // 删除这一行
            }
            return true
        }
        
        if modified {
            let newContent = lines.joined(separator: "\n")
            do {
                try newContent.write(toFile: toolVersionsPath, atomically: true, encoding: .utf8)
                print("✅ [DEBUG] 已从 ~/.tool-versions 中删除 \(languageId) 的配置")
            } catch {
                print("❌ [DEBUG] 删除 ~/.tool-versions 中的配置失败: \(error)")
            }
        }
    }
    
    /// 从所有 shell 配置文件中删除或注释系统版本配置
    private func removeSystemVersionConfigFromShellConfigs(languageId: String) {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let shellConfigFiles = [
            "\(homeDir)/.zshrc",
            "\(homeDir)/.bashrc",
            "\(homeDir)/.bash_profile",
            "\(homeDir)/.zprofile",
            "\(homeDir)/.profile"
        ]
        
        for configPath in shellConfigFiles {
            self.removeSystemVersionConfigFromShellConfig(configPath: configPath, languageId: languageId)
        }
    }
    
    /// 从指定的 shell 配置文件中删除或注释系统版本配置
    private func removeSystemVersionConfigFromShellConfig(configPath: String, languageId: String) {
        let fileManager = FileManager.default
        
        // 如果文件不存在，直接返回
        guard fileManager.fileExists(atPath: configPath),
              var content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return
        }
        
        let markerStart = "# MacEnvSwitcher: System \(languageId) version configuration"
        let markerEnd = "# End MacEnvSwitcher system \(languageId) configuration"
        
        // 查找并删除系统版本配置块
        while let startRange = content.range(of: markerStart),
              let endRange = content.range(of: markerEnd, range: startRange.upperBound..<content.endIndex) {
            content.removeSubrange(startRange.lowerBound..<endRange.upperBound)
            let fileName = (configPath as NSString).lastPathComponent
            print("🗑️ [DEBUG] 已从 \(fileName) 中删除系统 \(languageId) 版本配置块")
        }
        
        // 写入更新后的内容
        do {
            try content.write(toFile: configPath, atomically: true, encoding: .utf8)
        } catch {
            print("❌ [DEBUG] 更新 \(configPath) 失败: \(error)")
        }
    }
    
    /// 检查 shell 配置文件中是否存在系统版本配置
    private func hasSystemVersionConfigInShellConfigs(languageId: String) -> Bool {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let shellConfigFiles = [
            "\(homeDir)/.zshrc",
            "\(homeDir)/.bashrc",
            "\(homeDir)/.bash_profile",
            "\(homeDir)/.zprofile",
            "\(homeDir)/.profile"
        ]
        
        for configPath in shellConfigFiles {
            if self.hasSystemVersionConfigInShellConfig(configPath: configPath, languageId: languageId) {
                return true
            }
        }
        return false
    }
    
    /// 检查指定的 shell 配置文件中是否存在系统版本配置
    private func hasSystemVersionConfigInShellConfig(configPath: String, languageId: String) -> Bool {
        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return false
        }
        
        let markerStart = "# MacEnvSwitcher: System \(languageId) version configuration"
        return content.contains(markerStart)
    }
    
    /// 从 shell 配置文件中检测系统版本
    private func detectSystemVersionFromConfig(languageId: String) -> String? {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let zshrcPath = "\(homeDir)/.zshrc"
        
        guard let content = try? String(contentsOfFile: zshrcPath, encoding: .utf8) else {
            return nil
        }
        
        let markerStart = "# MacEnvSwitcher: System \(languageId) version configuration"
        let markerEnd = "# End MacEnvSwitcher system \(languageId) configuration"
        
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
            
        case "golang", "go":
            if let goRootMatch = configBlock.range(of: #"export GOROOT="([^"]+)""#, options: .regularExpression) {
                // 可以从路径中提取版本，或者执行命令检测
            }
            
        default:
            break
        }
        
        return nil
    }
    
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
                asdfInstalledVersions: [],
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
