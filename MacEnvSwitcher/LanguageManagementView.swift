import SwiftUI
import AppKit

// 语言管理主界面
struct LanguageManagementView: View {
    @StateObject private var viewModel = LanguageManagementViewModel()
    @State private var selectedLanguage: ProgrammingLanguage?
    @State private var showingAddLanguage = false
    
    // 排序后的语言列表
    var sortedLanguages: [ProgrammingLanguage] {
        switch viewModel.sortMode {
        case .uninstalled:
            // 未安装的在前，然后按名称排序
            // 判断标准：没有已安装版本 或 没有当前版本 的视为未安装
            return viewModel.languages.sorted { lhs, rhs in
                let lhsReallyInstalled = lhs.installedVersions.count > 0 || lhs.currentVersion != nil
                let rhsReallyInstalled = rhs.installedVersions.count > 0 || rhs.currentVersion != nil
                
                if lhsReallyInstalled != rhsReallyInstalled {
                    return !lhsReallyInstalled  // 未安装的在前
                }
                return lhs.displayName < rhs.displayName
            }
        case .installed:
            // 已安装的在前，然后按名称排序
            // 判断标准：有已安装版本 或 有当前版本 的视为已安装
            return viewModel.languages.sorted { lhs, rhs in
                let lhsReallyInstalled = lhs.installedVersions.count > 0 || lhs.currentVersion != nil
                let rhsReallyInstalled = rhs.installedVersions.count > 0 || rhs.currentVersion != nil
                
                if lhsReallyInstalled != rhsReallyInstalled {
                    return lhsReallyInstalled  // 已安装的在前
                }
                return lhs.displayName < rhs.displayName
            }
        case .name:
            // 按名称排序
            return viewModel.languages.sorted { $0.displayName < $1.displayName }
        case .custom:
            // 保持原有顺序（用户可以手动调整）
            return viewModel.languages
        }
    }
    
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
                
                // 排序选项工具栏
                HStack {
                    Text(tr("Sort"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $viewModel.sortMode) {
                        Text(tr("Uninstalled First")).tag(LanguageSortMode.uninstalled)
                        Text(tr("Installed First")).tag(LanguageSortMode.installed)
                        Text(tr("By Name")).tag(LanguageSortMode.name)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                
                Divider()
                
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(sortedLanguages) { language in
                            LanguageCard(
                                language: language,
                                isSelected: selectedLanguage?.id == language.id,
                                viewModel: viewModel
                            )
                            .onTapGesture {
                                // 切换语言时，清除之前的加载状态
                                if let previousLang = selectedLanguage, previousLang.id != language.id {
                                    viewModel.clearLoadingStateIfNeeded(for: language.id)
                                }
                                selectedLanguage = language
                            }
                            .onChange(of: viewModel.languages.count) { _ in
                                // 如果语言被删除，取消选择
                                if let selectedId = selectedLanguage?.id, !viewModel.languages.contains(where: { $0.id == selectedId }) {
                                    selectedLanguage = nil
                                }
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
    @ObservedObject var viewModel: LanguageManagementViewModel
    @State private var showDeleteAlert = false
    
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
                    Text(tr("Installed (not set as global)"))
                        .font(.caption)
                        .foregroundColor(.blue)
                } else {
                    Text(tr("Not Installed"))
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            // 状态指示器：只有真正安装了版本（有已安装版本或当前版本）才显示绿色勾选
            let reallyInstalled = language.installedVersions.count > 0 || language.currentVersion != nil
            if reallyInstalled {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 16))
            }
            
            // 删除按钮（鼠标悬停或选中时显示）
            Button(action: {
                showDeleteAlert = true
            }) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .opacity(isSelected ? 1.0 : 0.3)
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .alert(tr("Delete Language"), isPresented: $showDeleteAlert) {
            Button(tr("Cancel"), role: .cancel) { }
            Button(tr("Delete"), role: .destructive) {
                viewModel.removeLanguage(language)
            }
        } message: {
            Text(String(format: tr("Are you sure you want to delete language '%@'?\nThis will remove it from the language list, but will not uninstall installed versions."), language.displayName))
        }
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
    @State private var versionLoadingStartTime: Date? = nil
    @State private var showVersionLoadingTimeout: Bool = false
    @State private var showTerminalCommandCopied: Bool = false
    @State private var showVersionDetails: Bool = false
    @State private var versionDetailInfo: VersionDetailInfo?
    
    // 直接从 viewModel.languages 获取最新的语言数据
    // SwiftUI 会自动响应 @Published 属性的变化
    private var currentLanguage: ProgrammingLanguage? {
        viewModel.languages.first(where: { $0.id == language.id })
    }
    
    // 版本详情信息结构
    struct VersionDetailInfo {
        let language: ProgrammingLanguage
        let version: String
        let versionSource: VersionSource
        let versionPath: String?
        let asdfGlobalVersion: String?
        let executablePath: String?
        let allInstalledVersions: [String]
        let asdfInstalledVersions: [String]
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
                    Text(tr("Current Global Version"))
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
                                
                            Button(tr("View Details")) {
                                    // 收集版本详细信息
                                    let toolName: String = {
                                        switch lang.id {
                                        case "nodejs": return "node"
                                        case "golang": return "go"
                                        default: return lang.id
                                        }
                                    }()
                                    
                                    // 获取可执行文件路径
                                    let whichResult = Shell.run("which \(toolName) 2>/dev/null")
                                    let executablePath = whichResult.code == 0 && !whichResult.out.isEmpty
                                        ? whichResult.out.trimmingCharacters(in: .whitespacesAndNewlines)
                                        : nil
                                    
                                    // 创建详情信息
                                    versionDetailInfo = VersionDetailInfo(
                                        language: lang,
                                        version: currentVersion,
                                        versionSource: lang.versionSource,
                                        versionPath: lang.versionPath,
                                        asdfGlobalVersion: lang.asdfGlobalVersion,
                                        executablePath: executablePath,
                                        allInstalledVersions: lang.installedVersions,
                                        asdfInstalledVersions: lang.asdfInstalledVersions
                                    )
                                    showVersionDetails = true
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
                                        Text(tr("asdf global configuration set"))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                } else if lang.asdfGlobalVersion != currentVersion {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                            .font(.caption)
                                        Text(tr("Current version differs from asdf global configuration"))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            } else if lang.versionSource != .asdf && lang.asdfGlobalVersion != nil {
                                HStack {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                    Text(String(format: tr("asdf configured but currently using %@ version"), lang.versionSource.displayName))
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
                        Text(tr("No global version set"))
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
                        Text(tr("Installed Versions"))
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
                        Text(tr("No versions installed yet"))
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
                    Text(tr("Install New Version"))
                        .font(.headline)
                    
                    // 版本选择方式
                    Picker("", selection: $viewModel.versionSelectionMode) {
                        Text(tr("Select from List")).tag(VersionSelectionMode.fromList)
                        Text(tr("Manual Input")).tag(VersionSelectionMode.manual)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    if viewModel.versionSelectionMode == .fromList {
                        // 可用版本下拉列表
                        VStack(alignment: .leading, spacing: 8) {
                            // 直接显示版本选择框，不显示"可用版本"标题
                            if let lang = currentLanguage {
                                // 检查是否应该显示加载状态
                                // 如果版本列表为空，且没有超时，则显示加载动画
                                let isLoading = lang.availableVersions.isEmpty && !showVersionLoadingTimeout
                                
                                if isLoading {
                            HStack {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text(tr("Loading version list..."))
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .onAppear {
                                        // 记录加载开始时间
                                        if versionLoadingStartTime == nil {
                                            versionLoadingStartTime = Date()
                                            let currentLangId = lang.id
                                            
                                            // 5秒后如果还在加载，停止显示加载动画
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                                                // 检查当前语言是否仍然是同一个，且版本列表仍为空
                                                if let currentLang = self.currentLanguage,
                                                   currentLang.id == currentLangId,
                                                   currentLang.availableVersions.isEmpty {
                                                    self.showVersionLoadingTimeout = true
                                                    // 如果超时后还是没有版本，显示预设版本
                                                    if let index = self.viewModel.languages.firstIndex(where: { $0.id == currentLangId }) {
                                                        let predefinedVersions = SoftConfig.getPredefinedVersions(for: currentLangId)
                                                        if !predefinedVersions.isEmpty {
                                                            self.viewModel.languages[index].availableVersions = predefinedVersions
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                } else {
                                    // 显示版本选择器
                                    let versionsToShow = lang.availableVersions.isEmpty 
                                        ? SoftConfig.getPredefinedVersions(for: lang.id)
                                        : lang.availableVersions
                                    
                                    if !versionsToShow.isEmpty {
                                        HStack(spacing: 12) {
                                            // "选择版本"标签 - 左侧
                                            Text(tr("Select Version"))
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .frame(width: 80, alignment: .leading)
                                            
                                            // 版本选择下拉框 - 中间位置（"这里"的位置）
                                            Picker("", selection: $selectedVersion) {
                                                Text(tr("Select Version...")).tag("")
                                                ForEach(versionsToShow, id: \.self) { version in
                                                    Text(version).tag(version)
                                                }
                                            }
                                            .labelsHidden()
                                            .frame(minWidth: 350, maxWidth: .infinity)
                                            .frame(height: 50)
                                            
                                            // 刷新列表按钮 - 右侧
                                            Button(tr("Refresh List")) {
                                                if let lang = currentLanguage {
                                                    viewModel.loadAvailableVersions(language: lang)
                                                }
                                            }
                                            .font(.caption)
                                        }
                                    } else {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(tr("No available versions"))
                                                .foregroundColor(.secondary)
                                            
                                            // 添加提示信息
                                            Text("💡 \(tr("Tip:"))")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                            
                                            // 针对 npm 的特殊提示
                                            if lang.id == "npm" {
                                                Text(tr("npm usually comes with Node.js and doesn't need separate installation."))
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                Text(tr("You can:"))
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                Text(tr("1. Install Node.js, npm will be included automatically"))
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                Text(tr("2. Use \"Manual Input\" to enter version number"))
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                Text(tr("3. Check if Node.js is installed: node --version"))
                                                    .font(.system(.caption2, design: .monospaced))
                                                    .foregroundColor(.secondary)
                                            } else {
                                                Text(tr("This language may not have a predefined version list, or version loading failed."))
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                Text(tr("You can:"))
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                Text(tr("1. Click \"Refresh List\" to reload versions"))
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                Text(tr("2. Use \"Manual Input\" to enter version number"))
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                Text(String(format: tr("3. Install manually in terminal: %@"), getInstallCommand(for: lang.id, version: "latest")))
                                                    .font(.system(.caption2, design: .monospaced))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .frame(maxWidth: 520, alignment: .leading)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 8)
                                        .background(Color.orange.opacity(0.1))
                                        .cornerRadius(6)
                                    }
                                }
                            }
                            
                            // 安装提示和终端按钮 - 移到选择框下方
                            if let lang = currentLanguage, !lang.availableVersions.isEmpty || !SoftConfig.getPredefinedVersions(for: lang.id).isEmpty {
                                HStack(spacing: 8) {
                                    Text(tr("Tip: If installation fails, please check the official website for installation tutorials or try entering commands in the terminal"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                    
                                    Spacer()
                                    
                                    // 命令显示和复制按钮
                                    HStack(spacing: 4) {
                                        let installCommand = getInstallCommand(for: lang.id, version: selectedVersion.isEmpty ? "latest" : selectedVersion)
                                        
                                        Text(installCommand)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundColor(.primary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(NSColor.controlBackgroundColor))
                                            .cornerRadius(4)
                                            .onTapGesture {
                                                // 点击复制到剪贴板
                                                copyToClipboard(installCommand)
                                                showTerminalCommandCopied = true
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                                    showTerminalCommandCopied = false
                                                }
                                            }
                                        
                                        Button(action: {
                                            let cmd = getInstallCommand(for: lang.id, version: selectedVersion.isEmpty ? "latest" : selectedVersion)
                                            copyToClipboard(cmd)
                                            showTerminalCommandCopied = true
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                                showTerminalCommandCopied = false
                                            }
                                        }) {
                                            Image(systemName: showTerminalCommandCopied ? "checkmark.circle.fill" : "doc.on.doc")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        
                                        Button(action: {
                                            let cmd = getInstallCommand(for: lang.id, version: selectedVersion.isEmpty ? "latest" : selectedVersion)
                                            openTerminalWithCommand(cmd)
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "terminal")
                                                Text(tr("Open Terminal"))
                                            }
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.blue.opacity(0.1))
                                            .foregroundColor(.blue)
                                            .cornerRadius(4)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                    } else {
                        // 手动输入版本号
                        VStack(alignment: .leading, spacing: 8) {
                            Text(tr("Enter Version Number"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            TextField("例如: 3.12.0", text: $customVersionInput)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Text(tr("Tip: Please enter the full version number, such as 3.12.0 or latest"))
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
                                Text(tr("Installing..."))
                            } else {
                                Image(systemName: "arrow.down.circle.fill")
                                Text(tr("Install Version"))
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
        .alert(tr("Operation Successful"), isPresented: $showSuccessAlert) {
            Button(tr("OK"), role: .cancel) { }
        } message: {
            Text(successMessage)
        }
        .alert(tr("System Version Alert"), isPresented: $showSystemVersionAlert) {
            Button(tr("OK"), role: .cancel) { }
        } message: {
            Text(systemVersionMessage)
        }
        .sheet(isPresented: $showVersionDetails) {
            if let detailInfo = versionDetailInfo {
                VersionDetailView(detailInfo: detailInfo)
            }
        }
        .onAppear {
            if let lang = currentLanguage {
                // 如果切换了语言，清除之前的加载状态
                viewModel.clearLoadingStateIfNeeded(for: lang.id)
                // 重置加载状态
                versionLoadingStartTime = nil
                showVersionLoadingTimeout = false
                viewModel.loadAvailableVersions(language: lang)
        }
        }
        .onChange(of: currentLanguage?.id) { _ in
            // 语言切换时重置加载状态
            versionLoadingStartTime = nil
            showVersionLoadingTimeout = false
        }
        // SwiftUI 会自动响应 @ObservedObject 中 @Published 属性的变化
        // 不需要额外的 onChange 监听
    }
    
    /// 获取安装命令
    private func getInstallCommand(for languageId: String, version: String) -> String {
        // 根据语言类型生成不同的安装命令
        switch languageId {
        case "php":
            if version == "latest" || version.isEmpty {
                return "brew install php"
            } else {
                let brewVersion = extractBrewPhpVersion(from: version) ?? "8.4"
                return "brew install php@\(brewVersion)"
            }
        case "fastlane":
            if version == "latest" || version.isEmpty {
                return "brew install fastlane"
            } else {
                return "gem install fastlane -v \(version) -NV"
            }
        case "nodejs":
            if version == "latest" || version.isEmpty {
                return "brew install node"
            } else {
                return "asdf install nodejs \(version)"
            }
        default:
            // 其他语言优先使用 asdf
            if version == "latest" || version.isEmpty {
                return "brew install \(languageId)"
            } else {
                return "asdf install \(languageId) \(version)"
            }
        }
    }
    
    /// 提取 Homebrew PHP 版本格式
    private func extractBrewPhpVersion(from version: String) -> String? {
        if let match = version.range(of: #"^(\d+\.\d+)"#, options: .regularExpression) {
            return String(version[match])
        }
        return nil
    }
    
    /// 复制到剪贴板
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    /// 打开终端并执行命令
    private func openTerminalWithCommand(_ command: String) {
        // 优先尝试使用 iTerm2
        let iTermCheck = Shell.run("osascript -e 'tell application \"System Events\" to return exists process \"iTerm2\"'")
        let isiTermRunning = iTermCheck.out.contains("true")
        
        let iTermInstalled = Shell.run("[ -d /Applications/iTerm.app ] && echo YES || echo NO")
        let hasiTerm = iTermInstalled.out.contains("YES")
        
        if hasiTerm || isiTermRunning {
            // 使用 iTerm2
            let script = """
            tell application "iTerm2"
                if is running then
                    tell current window
                        create tab with default profile
                        tell current session of current tab
                            write text "\(command)"
                        end tell
                    end tell
                else
                    activate
                    tell current window
                        tell current session of current tab
                            write text "\(command)"
                        end tell
                    end tell
                end if
            end tell
            """
            
            let result = Shell.run("osascript -e '\(script)'")
            if result.code != 0 {
                // 如果 iTerm2 失败，尝试系统终端
                openSystemTerminalWithCommand(command)
            }
        } else {
            // 使用系统默认终端
            openSystemTerminalWithCommand(command)
        }
    }
    
    /// 打开系统默认终端并执行命令
    private func openSystemTerminalWithCommand(_ command: String) {
        // 使用 AppleScript 打开 Terminal.app 并执行命令
        let script = """
        tell application "Terminal"
            activate
            do script "\(command)"
        end tell
        """
        
        _ = Shell.run("osascript -e '\(script)'")
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
                Text(tr("(System)"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(3)
            }
            
            if isCurrent {
                Text(tr("(Global)"))
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
                    Text(tr("Set"))
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
                        Text(isSettingGlobal ? tr("Setting...") : tr("Set as Global"))
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
            .alert(tr("Confirm Uninstall"), isPresented: $showingUninstallAlert) {
                Button(tr("Cancel"), role: .cancel) { }
                Button(tr("Uninstall"), role: .destructive) {
                    onUninstall()
                }
            } message: {
                Text(String(format: tr("Are you sure you want to uninstall version %@?"), version))
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
        case .system: return tr("System")
        case .other: return tr("Other")
        case .notInstalled: return tr("Not Installed")
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

enum LanguageSortMode {
    case name          // 按名称排序
    case installed     // 已安装的在前
    case uninstalled   // 未安装的在前（默认）
    case custom        // 自定义排序（保留用户手动调整的顺序）
}

// 视图模型
class LanguageManagementViewModel: ObservableObject {
    @Published var languages: [ProgrammingLanguage] = []
    @Published var versionSelectionMode: VersionSelectionMode = .fromList
    @Published var sortMode: LanguageSortMode = .uninstalled  // 默认未安装的在前
    
    private let installers = Installers()
    private let detectors = Detectors()
    
    // 跟踪正在加载版本列表的语言ID，避免重复加载和状态混乱
    private var loadingVersionsForLanguageId: String? = nil
    
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
            ),
            ProgrammingLanguage(
                id: "gradle",
                displayName: "Gradle",
                description: "强大的构建自动化工具",
                icon: "hammer.fill",
                color: .green,
                isInstalled: false,
                installedVersions: [],
                asdfInstalledVersions: [],
                availableVersions: []
            ),
            ProgrammingLanguage(
                id: "fastlane",
                displayName: "Fastlane",
                description: "iOS 和 Android 应用自动化构建和发布工具",
                icon: "speedometer",
                color: .blue,
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
        let taskId = UUID().uuidString.prefix(8)
        
        print("🚀 [DEBUG-\(taskId)] 开始刷新语言状态: \(language.id) (index=\(index))")
        
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
            
            // 对于 Fastlane，额外检测 Homebrew 和 gem 安装的版本
            if language.id == "fastlane" {
                print("🔍 [DEBUG-\(taskId)] 开始检测 fastlane 安装状态...")
                // fastlane --version 输出多行，版本号在最后一行，使用 tail -1 获取最后一行
                let versionResult = Shell.run("fastlane --version 2>/dev/null | tail -1")
                print("🔍 [DEBUG-\(taskId)] fastlane --version 执行结果: code=\(versionResult.code), output=\(versionResult.out.trimmingCharacters(in: .whitespacesAndNewlines))")
                
                // 如果 tail -1 失败，尝试获取完整输出并查找版本号
                var output = versionResult.out.trimmingCharacters(in: .whitespacesAndNewlines)
                if output.isEmpty || !output.contains("fastlane") {
                    let fullOutputResult = Shell.run("fastlane --version 2>/dev/null")
                    print("🔍 [DEBUG-\(taskId)] fastlane --version 完整输出:\n\(fullOutputResult.out)")
                    // 从完整输出中查找包含版本号的行
                    let lines = fullOutputResult.out.components(separatedBy: .newlines)
                    for line in lines.reversed() {
                        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmedLine.contains("fastlane") && trimmedLine.range(of: #"\d+\.\d+\.\d+"#, options: .regularExpression) != nil {
                            output = trimmedLine
                            break
                        }
                    }
                }
                
                if versionResult.code == 0 || !output.isEmpty {
                    // 提取版本号 fastlane 2.228.0 -> 2.228.0
                    var version: String? = nil
                    if let versionMatch = output.range(of: #"fastlane (\d+\.\d+\.\d+)"#, options: .regularExpression) {
                        let fullMatch = String(output[versionMatch])
                        version = fullMatch.replacingOccurrences(of: "fastlane ", with: "")
                    } else if let versionMatch = output.range(of: #"\d+\.\d+\.\d+"#, options: .regularExpression) {
                        version = String(output[versionMatch])
                    }
                    
                    if let ver = version {
                        print("🔍 [DEBUG-\(taskId)] 提取到 fastlane 版本: \(ver)")
                        
                        // 检查安装来源
                        var isHomebrew = false
                        var isGem = false
                        var detectedPath: String? = nil
                        
                        // 检查路径判断来源
                        let whichResult = Shell.run("which fastlane 2>/dev/null")
                        if whichResult.code == 0 {
                            let pathString = whichResult.out.trimmingCharacters(in: .whitespacesAndNewlines)
                            detectedPath = pathString
                            print("🔍 [DEBUG-\(taskId)] which fastlane 路径: \(pathString)")
                            
                            if !pathString.isEmpty {
                                if pathString.contains("/opt/homebrew/") || pathString.contains("/usr/local/bin/") || pathString.contains("/usr/local/opt/") {
                                    isHomebrew = true
                                    print("🔍 [DEBUG-\(taskId)] 通过路径判断为 Homebrew 安装")
                                } else if pathString.contains("/.gem/") || pathString.contains("/usr/local/lib/ruby") || pathString.contains("/System/Library/Frameworks/Ruby.framework") {
                                    isGem = true
                                    print("🔍 [DEBUG-\(taskId)] 通过路径判断为 gem 安装")
                                }
                            }
                        }
                        
                        // 如果路径判断失败，通过 brew list 判断
                        if !isHomebrew && !isGem {
                            let brewCheck = Shell.run("brew list fastlane 2>/dev/null")
                            print("🔍 [DEBUG-\(taskId)] brew list fastlane 结果: code=\(brewCheck.code), output=\(brewCheck.out.trimmingCharacters(in: .whitespacesAndNewlines))")
                            if brewCheck.code == 0 || brewCheck.out.contains("fastlane") {
                                isHomebrew = true
                                print("🔍 [DEBUG-\(taskId)] 通过 brew list 判断为 Homebrew 安装")
                            } else {
                                // 检查 gem
                                let gemCheck = Shell.run("gem list fastlane --local 2>/dev/null | grep fastlane")
                                print("🔍 [DEBUG-\(taskId)] gem list fastlane 结果: code=\(gemCheck.code), output=\(gemCheck.out.trimmingCharacters(in: .whitespacesAndNewlines))")
                                if gemCheck.code == 0, !gemCheck.out.isEmpty {
                                    isGem = true
                                    print("🔍 [DEBUG-\(taskId)] 通过 gem list 判断为 gem 安装")
                                }
                            }
                        }
                        
                        // 添加到已安装版本列表
                        if !installedVersions.contains(ver) {
                            installedVersions.append(ver)
                            if isHomebrew {
                                print("✅ [DEBUG-\(taskId)] 检测到 Homebrew 安装的 fastlane: \(ver), 路径: \(detectedPath ?? "未知")")
                            } else if isGem {
                                print("✅ [DEBUG-\(taskId)] 检测到 gem 安装的 fastlane: \(ver), 路径: \(detectedPath ?? "未知")")
                            } else {
                                print("✅ [DEBUG-\(taskId)] 检测到 fastlane: \(ver), 路径: \(detectedPath ?? "未知")")
                            }
                        } else {
                            print("ℹ️ [DEBUG-\(taskId)] fastlane 版本 \(ver) 已在已安装列表中")
                        }
                    } else {
                        print("⚠️ [DEBUG-\(taskId)] 无法从输出中提取 fastlane 版本号: \(output)")
                    }
                } else {
                    print("⚠️ [DEBUG-\(taskId)] fastlane --version 执行失败或输出为空")
                }
                print("✅ [DEBUG-\(taskId)] fastlane 检测完成，installedVersions.count=\(installedVersions.count), installedVersions=\(installedVersions)")
            } else {
                print("ℹ️ [DEBUG-\(taskId)] 不是 fastlane，跳过 fastlane 特殊检测逻辑")
            }
            
            print("🔍 [DEBUG-\(taskId)] 步骤3完成，准备检测系统安装版本，language.id=\(language.id), installedVersions.count=\(installedVersions.count)")
            
            // 对于其他语言，也尝试检测系统安装的版本
            // 通过检测系统路径中的可执行文件来判断
            // 即使 asdf 插件已安装但没有版本，也应该检测系统版本
            // 注意：fastlane 已经在上面特殊检测中处理了，这里跳过避免重复检测
            if language.id != "fastlane" {
                if let systemVersion = LanguageDetector.detectSystemInstalledVersion(languageId: language.id) {
                    // 如果系统版本不在列表中，添加到列表
                    if !installedVersions.contains(systemVersion) {
                        installedVersions.append(systemVersion)
                        print("🔍 [DEBUG-\(taskId)] 检测到系统安装的 \(language.id): \(systemVersion)")
                    }
                } else {
                    print("ℹ️ [DEBUG-\(taskId)] 未检测到系统安装的 \(language.id)")
                }
            } else {
                print("ℹ️ [DEBUG-\(taskId)] fastlane 已在特殊检测中处理，跳过系统安装版本检测")
            }
            
            print("🔍 [DEBUG-\(taskId)] 步骤3.5完成，installedVersions.count=\(installedVersions.count), installedVersions=\(installedVersions)")
            
            // 4. 检测当前实际使用的版本和来源（使用统一的 LanguageDetector）
            print("🔍 [DEBUG-\(taskId)] 准备调用 LanguageDetector.detectCurrentVersionAndSource for \(language.id)")
            let detectionResult = LanguageDetector.detectCurrentVersionAndSource(
                languageId: language.id,
                asdfPluginInstalled: asdfPluginInstalled,
                asdfGlobalVersion: asdfGlobalVersion
            )
            var currentVersion = detectionResult.version
            var versionSource = detectionResult.source
            var versionPath = detectionResult.path
            
            print("🔍 [DEBUG-\(taskId)] LanguageDetector 返回结果: \(language.id) - version=\(currentVersion ?? "nil"), source=\(versionSource), path=\(versionPath ?? "nil")")
            
            // 对于 fastlane，如果检测到了已安装版本但 currentVersion 为空，手动设置
            if language.id == "fastlane" {
                print("🔍 [DEBUG-\(taskId)] fastlane 检测后检查: currentVersion=\(currentVersion ?? "nil"), installedVersions.count=\(installedVersions.count)")
                if currentVersion == nil && !installedVersions.isEmpty {
                    print("🔍 [DEBUG-\(taskId)] fastlane currentVersion 为空，执行手动设置逻辑")
                // 使用已安装列表中的第一个版本作为当前版本
                currentVersion = installedVersions.first
                // 通过检查路径判断来源
                let whichResult = Shell.run("which fastlane 2>/dev/null")
                if whichResult.code == 0 {
                    let pathString = whichResult.out.trimmingCharacters(in: .whitespacesAndNewlines)
                    if pathString.contains("/opt/homebrew/") || pathString.contains("/usr/local/bin/") || pathString.contains("/usr/local/opt/") {
                        versionSource = .homebrew
                        versionPath = pathString
                    } else if pathString.contains("/.gem/") || pathString.contains("/usr/local/lib/ruby") || pathString.contains("/System/Library/Frameworks/Ruby.framework") {
                        versionSource = .other
                        versionPath = pathString
                    } else {
                        versionSource = .other
                        versionPath = pathString
                    }
                } else {
                    // 如果 which 找不到，尝试通过 brew list 判断
                    let brewCheck = Shell.run("brew list fastlane 2>/dev/null")
                    if brewCheck.code == 0 || brewCheck.out.contains("fastlane") {
                        versionSource = .homebrew
                    } else {
                        versionSource = .other
                    }
                }
                    print("✅ [DEBUG-\(taskId)] fastlane 自动设置当前版本: \(currentVersion ?? "nil"), 来源: \(versionSource)")
                } else if currentVersion != nil {
                    print("✅ [DEBUG-\(taskId)] fastlane currentVersion 已存在，无需手动设置: \(currentVersion ?? "nil")")
                } else {
                    print("⚠️ [DEBUG-\(taskId)] fastlane currentVersion 为空且 installedVersions 也为空")
                }
            }
            
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
            // 只有真正安装了版本（有已安装版本或当前版本）才认为是已安装
            // 仅仅有 asdf 插件但没有安装任何版本，不算已安装
            let isInstalled = installedVersions.count > 0 || 
                             (currentVersion != nil && versionSource != .notInstalled)
            
            print("📊 [DEBUG-\(taskId)] 安装状态判断: \(language.id) - isInstalled=\(isInstalled), installedVersions.count=\(installedVersions.count), currentVersion=\(currentVersion ?? "nil"), versionSource=\(versionSource), asdfPluginInstalled=\(asdfPluginInstalled)")
            if language.id == "fastlane" {
                print("🔍 [DEBUG-\(taskId)] fastlane 详细状态: installedVersions=\(installedVersions), currentVersion=\(currentVersion ?? "nil"), versionSource=\(versionSource), isInstalled=\(isInstalled)")
            }
            
            DispatchQueue.main.async {
                print("🎯 [DEBUG-\(taskId)] 进入主线程更新UI: \(language.id)")
                // 确保索引仍然有效
                guard index < self.languages.count else {
                    print("⚠️ [DEBUG-\(taskId)] 索引无效: index=\(index), languages.count=\(self.languages.count)")
                    return
                }
                
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
                
                print("✅ [DEBUG-\(taskId)] 刷新后状态: \(language.id) currentVersion=\(updatedLanguage.currentVersion ?? "nil"), asdfGlobalVersion=\(updatedLanguage.asdfGlobalVersion ?? "nil"), isInstalled=\(updatedLanguage.isInstalled), installedVersions.count=\(updatedLanguage.installedVersions.count)")
                if language.id == "fastlane" {
                    print("🔍 [DEBUG-\(taskId)] fastlane UI更新前: currentVersion=\(updatedLanguage.currentVersion ?? "nil"), versionSource=\(updatedLanguage.versionSource), isInstalled=\(updatedLanguage.isInstalled), installedVersions=\(updatedLanguage.installedVersions)")
                }
                
                // 替换整个对象以触发视图更新
                self.languages[index] = updatedLanguage
                
                // 手动触发视图更新（关键：确保 SwiftUI 检测到数组元素的变化）
                self.objectWillChange.send()
                
                print("✅ [DEBUG-\(taskId)] UI更新完成: \(language.id) - 已设置 languages[\(index)] = \(updatedLanguage.displayName), isInstalled=\(updatedLanguage.isInstalled), installedVersions.count=\(updatedLanguage.installedVersions.count)")
                
                // 验证更新是否成功
                if let verifyLang = self.languages.first(where: { $0.id == language.id }) {
                    print("🔍 [DEBUG-\(taskId)] 验证更新: \(language.id) - verifyLang.isInstalled=\(verifyLang.isInstalled), verifyLang.installedVersions.count=\(verifyLang.installedVersions.count)")
                    if language.id == "fastlane" {
                        print("🔍 [DEBUG-\(taskId)] fastlane 验证详情: installedVersions=\(verifyLang.installedVersions), currentVersion=\(verifyLang.currentVersion ?? "nil")")
                    }
                }
                print("🏁 [DEBUG-\(taskId)] 刷新完成: \(language.id)")
            }
        }
    }
    
    // 注意：检测逻辑已迁移到 LanguageDetector 类
    // 保留此方法作为兼容层，但实际已使用 LanguageDetector
    private func detectCurrentVersionAndSource(
        languageId: String,
        asdfPluginInstalled: Bool,
        asdfGlobalVersion: String?
    ) -> (version: String?, source: VersionSource, path: String?) {
        let result = LanguageDetector.detectCurrentVersionAndSource(
            languageId: languageId,
            asdfPluginInstalled: asdfPluginInstalled,
            asdfGlobalVersion: asdfGlobalVersion
        )
        return (result.version, result.source, result.path)
    }
    
    // 保留旧的完整实现作为参考（将被删除）
    private func detectCurrentVersionAndSource_OLD(
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
            // 但只有当配置不为空时才使用
            if asdfPluginInstalled, let globalVer = asdfGlobalVersion, !globalVer.isEmpty {
                versionSource = .asdf
                currentVersion = globalVer
            } else if languageId == "php" {
                // 如果 asdf 没有配置，尝试检测系统版本（即使 which 找不到，也可能在其他路径）
                // 对于 PHP，可以尝试常见的安装路径
                let homebrewPhpPaths = [
                    "/opt/homebrew/opt/php/bin/php",
                    "/usr/local/opt/php/bin/php",
                    "/opt/homebrew/bin/php",
                    "/usr/local/bin/php",
                    "/usr/bin/php"
                ]
                
                for phpPath in homebrewPhpPaths {
                    let checkResult = Shell.run("test -f '\(phpPath)' && '\(phpPath)' --version 2>/dev/null | head -1")
                    if checkResult.code == 0, !checkResult.out.isEmpty {
                        // 判断路径类型
                        if phpPath.contains("/opt/homebrew/") || phpPath.contains("/usr/local/opt/") {
                            versionSource = .homebrew
                        } else {
                            versionSource = .system
                        }
                        
                        // 提取版本号
                        let output = checkResult.out
                        if let match = output.range(of: #"\d+\.\d+\.\d+"#, options: .regularExpression) {
                            currentVersion = String(output[match])
                        } else if let match = output.range(of: #"\d+\.\d+"#, options: .regularExpression) {
                            currentVersion = String(output[match])
                        }
                        
                        if currentVersion != nil {
                            break
                        }
                    }
                }
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
        
        // 对于 PHP，优先检查常见的 Homebrew 安装路径
        if languageId == "php" {
            let homebrewPhpPaths = [
                "/opt/homebrew/opt/php/bin/php",
                "/usr/local/opt/php/bin/php",
                "/opt/homebrew/bin/php",
                "/usr/local/bin/php",
                "/usr/bin/php"
            ]
            
            for phpPath in homebrewPhpPaths {
                let checkResult = Shell.run("test -f '\(phpPath)' && '\(phpPath)' --version 2>/dev/null | head -1")
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
            "kotlin": "kotlin -version 2>&1",
            "gradle": "gradle --version 2>&1 | head -1"
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
    
    /// 清除加载状态（如果需要）
    /// 当切换语言时调用，确保新语言可以开始加载
    func clearLoadingStateIfNeeded(for languageId: String) {
        // 如果当前正在加载的语言不是新选中的语言，清除加载状态
        if let loadingId = loadingVersionsForLanguageId, loadingId != languageId {
            print("🔄 [DEBUG] 切换语言：清除 \(loadingId) 的加载状态，准备加载 \(languageId)")
            loadingVersionsForLanguageId = nil
        }
    }
    
    /// PHP 安装的多种方式回退机制
    /// 1. 首先尝试 asdf 安装
    /// 2. 如果失败，尝试通过 Homebrew 安装指定版本
    /// 3. 最后考虑源码编译（通过 asdf，但会显示更详细的错误信息）
    private func installPhpWithFallback(version: String, log: inout String) -> Bool {
        // 方法1: 尝试 asdf 安装
        log += "📥 方法1: 尝试通过 asdf 安装 PHP \(version)...\n"
        let asdfResult = Shell.run("asdf install php \(version)", timeout: 600)
        log += asdfResult.out
        if !asdfResult.err.isEmpty {
            log += "\n⚠️ asdf 安装错误输出:\n\(asdfResult.err)"
        }
        
        if asdfResult.code == 0 {
            // 验证 asdf 安装是否成功
            let verifyResult = Shell.run("asdf list php 2>/dev/null | grep -w '\(version)'")
            if verifyResult.code == 0 && !verifyResult.out.isEmpty {
                log += "\n✅ asdf 安装成功！\n"
                return true
            }
        }
        
        log += "\n⚠️ asdf 安装失败，尝试方法2: Homebrew 安装...\n"
        
        // 方法2: 尝试通过 Homebrew 安装
        // PHP 版本格式通常是 8.3.12，需要转换为 brew 的格式 php@8.3
        let brewVersion = self.extractBrewPhpVersion(from: version)
        
        let brewCheck = Shell.run("which brew")
        if brewCheck.code == 0 {
            log += "📦 通过 Homebrew 安装 PHP...\n"
            
            // 1. 首先尝试安装最新版本的 PHP（brew install php）
            log += "   方法 2.1: 尝试安装 Homebrew 官方最新版本 PHP...\n"
            let checkInstalledSimple = Shell.run("brew list --formula php 2>/dev/null | head -1")
            if checkInstalledSimple.code == 0 {
                log += "✅ PHP 已通过 Homebrew 安装\n"
                // 验证安装
                let verifyResult = Shell.run("php --version 2>/dev/null | head -1")
                if verifyResult.code == 0 && !verifyResult.out.isEmpty {
                    log += "✅ 验证成功: \(verifyResult.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
                    return true
                }
            }
            
            // 尝试安装最新版本
            var brewInstallResult = Shell.run("brew install php", timeout: 600)
            log += brewInstallResult.out
            if !brewInstallResult.err.isEmpty {
                log += "\n⚠️ Homebrew 安装警告:\n\(brewInstallResult.err)"
            }
            
            // 如果最新版本安装成功，验证并返回
            if brewInstallResult.code == 0 {
                log += "\n✅ Homebrew 安装成功！\n"
                
                // 验证安装
                let verifyPaths = [
                    "/opt/homebrew/bin/php",
                    "/usr/local/bin/php",
                    "/opt/homebrew/opt/php/bin/php",
                    "/usr/local/opt/php/bin/php"
                ]
                
                var verified = false
                var verifiedPath: String? = nil
                var verifiedVersion: String? = nil
                
                for phpPath in verifyPaths {
                    let verifyCheck = Shell.run("test -f '\(phpPath)' && '\(phpPath)' --version 2>/dev/null | head -1")
                    if verifyCheck.code == 0 && !verifyCheck.out.isEmpty {
                        let output = verifyCheck.out.trimmingCharacters(in: .whitespacesAndNewlines)
                        log += "✅ 验证成功: \(output)\n"
                        
                        if let versionMatch = output.range(of: #"PHP (\d+\.\d+\.\d+)"#, options: .regularExpression) {
                            let fullMatch = String(output[versionMatch])
                            verifiedVersion = fullMatch.replacingOccurrences(of: "PHP ", with: "")
                        }
                        
                        verifiedPath = phpPath
                        verified = true
                        break
                    }
                }
                
                // 如果路径验证失败，尝试直接执行 php --version
                if !verified {
                    let directCheck = Shell.run("php --version 2>/dev/null | head -1")
                    if directCheck.code == 0 && !directCheck.out.isEmpty {
                        log += "✅ 验证成功（通过 PATH）: \(directCheck.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
                        
                        if let versionMatch = directCheck.out.range(of: #"PHP (\d+\.\d+\.\d+)"#, options: .regularExpression) {
                            let fullMatch = String(directCheck.out[versionMatch])
                            verifiedVersion = fullMatch.replacingOccurrences(of: "PHP ", with: "")
                        }
                        
                        verified = true
                        verifiedPath = "系统 PATH"
                    }
                }
                
                if verified {
                    log += "💡 注意: 此版本通过 Homebrew 安装，已添加到系统 PATH\n"
                    
                    // 尝试自动链接到 asdf
                    if let path = verifiedPath, path != "系统 PATH" {
                        let asdfInstallDir = FileManager.default.homeDirectoryForCurrentUser.path + "/.asdf/installs/php"
                        let asdfVersionPath = "\(asdfInstallDir)/\(verifiedVersion ?? version)"
                        let linkPath = path.replacingOccurrences(of: "/bin/php", with: "")
                        
                        let mkdirResult = Shell.run("mkdir -p '\(asdfInstallDir)'")
                        if mkdirResult.code == 0 {
                            let linkResult = Shell.run("ln -sf '\(linkPath)' '\(asdfVersionPath)'")
                            if linkResult.code == 0 {
                                log += "✅ 已自动链接到 asdf 管理\n"
                            }
                        }
                    }
                    
                    return true
                } else {
                    log += "⚠️ 安装成功但验证失败，请手动检查\n"
                }
            }
            
            // 2. 如果最新版本安装失败，且用户需要特定版本，尝试通过 shivammathur/php 安装
            if brewInstallResult.code != 0, let brewVersion = brewVersion {
                log += "   方法 2.2: 尝试通过 shivammathur/php 安装 PHP \(brewVersion)...\n"
                
                // 添加 tap
                log += "   添加 PHP tap (shivammathur/php)...\n"
                let tapResult = Shell.run("brew tap shivammathur/php 2>&1", timeout: 30)
                if tapResult.code == 0 || tapResult.out.contains("already tapped") || tapResult.err.contains("already tapped") {
                    log += "   ✅ Tap 已就绪\n"
                } else {
                    log += "   ⚠️ Tap 添加失败，继续尝试安装...\n"
                }
                
                // 检查是否已经安装特定版本
                let checkInstalled = Shell.run("brew list --formula php@\(brewVersion) 2>/dev/null || brew list php@\(brewVersion) 2>/dev/null | head -1")
                if checkInstalled.code == 0 {
                    log += "✅ PHP \(brewVersion) 已通过 Homebrew 安装\n"
                    return true
                }
                
                // 尝试通过 shivammathur/php 安装特定版本
                brewInstallResult = Shell.run("brew install shivammathur/php/php@\(brewVersion)", timeout: 600)
                
                // 如果失败，尝试官方 Homebrew 特定版本格式
                if brewInstallResult.code != 0 {
                    log += "   shivammathur/php 安装失败，尝试官方 Homebrew 特定版本格式...\n"
                    brewInstallResult = Shell.run("brew install php@\(brewVersion)", timeout: 600)
                }
                
                log += brewInstallResult.out
                if !brewInstallResult.err.isEmpty {
                    log += "\n⚠️ Homebrew 安装警告:\n\(brewInstallResult.err)"
                }
                
                if brewInstallResult.code == 0 {
                    log += "\n✅ Homebrew 安装成功！\n"
                    
                    // 验证安装 - 检查特定版本的路径
                    let verifyPaths = [
                        "/opt/homebrew/opt/php@\(brewVersion)/bin/php",
                        "/usr/local/opt/php@\(brewVersion)/bin/php",
                        "/opt/homebrew/bin/php",
                        "/usr/local/bin/php"
                    ]
                    
                    var verified = false
                    var verifiedPath: String? = nil
                    var verifiedVersion: String? = nil
                    
                    for phpPath in verifyPaths {
                        let verifyCheck = Shell.run("test -f '\(phpPath)' && '\(phpPath)' --version 2>/dev/null | head -1")
                        if verifyCheck.code == 0 && !verifyCheck.out.isEmpty {
                            let output = verifyCheck.out.trimmingCharacters(in: .whitespacesAndNewlines)
                            log += "✅ 验证成功: \(output)\n"
                            
                            // 提取版本号
                            if let versionMatch = output.range(of: #"PHP (\d+\.\d+\.\d+)"#, options: .regularExpression) {
                                let fullMatch = String(output[versionMatch])
                                verifiedVersion = fullMatch.replacingOccurrences(of: "PHP ", with: "")
                            }
                            
                            verifiedPath = phpPath
                            verified = true
                            break
                        }
                    }
                    
                    if verified {
                        log += "💡 注意: 此版本通过 Homebrew 安装，已添加到系统 PATH\n"
                        log += "   可以使用 'brew link php@\(brewVersion)' 来切换到该版本\n"
                        
                        // 尝试自动链接到 asdf（可选，提升用户体验）
                        if let path = verifiedPath, path != "系统 PATH" {
                            let asdfInstallDir = FileManager.default.homeDirectoryForCurrentUser.path + "/.asdf/installs/php"
                            let asdfVersionPath = "\(asdfInstallDir)/\(verifiedVersion ?? version)"
                            let linkPath = path.replacingOccurrences(of: "/bin/php", with: "")
                            
                            // 创建目录（如果不存在）
                            let mkdirResult = Shell.run("mkdir -p '\(asdfInstallDir)'")
                            if mkdirResult.code == 0 {
                                // 创建符号链接
                                let linkResult = Shell.run("ln -sf '\(linkPath)' '\(asdfVersionPath)'")
                                if linkResult.code == 0 {
                                    log += "✅ 已自动链接到 asdf 管理\n"
                                }
                            }
                        }
                        
                        return true
                    } else {
                        log += "⚠️ 安装成功但验证失败，请手动检查\n"
                    }
                } else {
                    log += "\n⚠️ Homebrew 安装失败\n"
                }
            } else if brewInstallResult.code != 0 {
                log += brewInstallResult.out
                if !brewInstallResult.err.isEmpty {
                    log += "\n⚠️ Homebrew 安装警告:\n\(brewInstallResult.err)"
                }
                log += "\n⚠️ Homebrew 安装失败\n"
            }
        } else {
            log += "⚠️ Homebrew 不可用，跳过此方法\n"
        }
        
        // 方法3: 如果前两种方法都失败，返回详细的错误信息和建议
        log += "\n❌ 所有安装方法均失败\n"
        log += "💡 建议:\n"
        log += "   1. 检查错误日志中的具体错误信息\n"
        log += "   2. 确保所有依赖已正确安装: brew install autoconf pkg-config libxml2 openssl\n"
        log += "   3. 尝试手动安装:\n"
        log += "      - asdf: asdf install php \(version)\n"
        if let brewVersion = brewVersion {
            log += "      - Homebrew: brew tap shivammathur/php && brew install shivammathur/php/php@\(brewVersion)\n"
            log += "      - 或官方: brew install php@\(brewVersion)\n"
        }
        log += "   4. 检查版本号是否正确（asdf 支持的版本可能与 Homebrew 不同）\n"
        log += "   5. 查看 PHP 官方文档: https://www.php.net/downloads\n"
        
        return false
    }
    
    /// 从 PHP 版本号中提取 Homebrew 版本格式
    /// 例如: 8.3.12 -> 8.3, 8.2.5 -> 8.2
    private func extractBrewPhpVersion(from version: String) -> String? {
        // 匹配主版本号和次版本号 (例如: 8.3.12 -> 8.3)
        if let match = version.range(of: #"^(\d+\.\d+)"#, options: .regularExpression) {
            return String(version[match])
        }
        return nil
    }
    
    /// Fastlane 安装的多种方式回退机制
    /// 1. 首先尝试 asdf 安装（如果插件可用）
    /// 2. 如果失败，尝试通过 Homebrew 安装（通常安装最新版本）
    /// 3. 最后尝试通过 gem 安装（RubyGems）
    private func installFastlaneWithFallback(version: String, log: inout String) -> Bool {
        // 方法1: 尝试 asdf 安装（如果插件可用）
        log += "📥 方法1: 尝试通过 asdf 安装 Fastlane \(version)...\n"
        let pluginCheck = Shell.run("asdf plugin list | grep -w 'fastlane'")
        if pluginCheck.code == 0 {
            let asdfResult = Shell.run("asdf install fastlane \(version)", timeout: 600)
            log += asdfResult.out
            if !asdfResult.err.isEmpty {
                log += "\n⚠️ asdf 安装错误输出:\n\(asdfResult.err)"
            }
            
            if asdfResult.code == 0 {
                // 验证 asdf 安装是否成功
                let verifyResult = Shell.run("asdf list fastlane 2>/dev/null | grep -w '\(version)'")
                if verifyResult.code == 0 && !verifyResult.out.isEmpty {
                    log += "\n✅ asdf 安装成功！\n"
                    return true
                }
            }
            log += "\n⚠️ asdf 安装失败或验证失败，尝试方法2...\n"
        } else {
            log += "⚠️ asdf fastlane 插件未安装，跳过 asdf 安装\n"
        }
        
        // 方法2: 尝试通过 Homebrew 安装（安装最新版本）
        log += "\n📦 方法2: 尝试通过 Homebrew 安装 Fastlane...\n"
        let brewCheck = Shell.run("which brew")
        if brewCheck.code == 0 {
            // 检查是否已经安装
            let checkInstalled = Shell.run("brew list --formula fastlane 2>/dev/null | head -1")
            if checkInstalled.code == 0 {
                log += "✅ Fastlane 已通过 Homebrew 安装\n"
                // 验证安装
                let verifyResult = Shell.run("fastlane --version 2>/dev/null | tail -1")
                if verifyResult.code == 0 && !verifyResult.out.isEmpty {
                    log += "✅ 验证成功: \(verifyResult.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
                    return true
                }
            }
            
            // 尝试安装
            log += "   安装 Homebrew Fastlane...\n"
            let brewInstallResult = Shell.run("brew install fastlane", timeout: 300)
            log += brewInstallResult.out
            if !brewInstallResult.err.isEmpty {
                log += "\n⚠️ Homebrew 安装警告:\n\(brewInstallResult.err)"
            }
            
            if brewInstallResult.code == 0 {
                log += "\n✅ Homebrew 安装成功！\n"
                // 验证安装
                let verifyResult = Shell.run("fastlane --version 2>/dev/null | tail -1")
                if verifyResult.code == 0 && !verifyResult.out.isEmpty {
                    log += "✅ 验证成功: \(verifyResult.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
                    return true
                } else {
                    log += "⚠️ 安装成功但验证失败，请手动检查\n"
                }
            } else {
                log += "\n⚠️ Homebrew 安装失败\n"
            }
        } else {
            log += "⚠️ Homebrew 不可用，跳过此方法\n"
        }
        
        // 方法3: 尝试通过 gem 安装（RubyGems）
        log += "\n💎 方法3: 尝试通过 RubyGems 安装 Fastlane...\n"
        let rubyCheck = Shell.run("which ruby")
        if rubyCheck.code == 0 {
            // 检查是否已经安装
            let checkInstalled = Shell.run("gem list fastlane --local 2>/dev/null | grep fastlane")
            if checkInstalled.code == 0 && !checkInstalled.out.isEmpty {
                log += "✅ Fastlane 已通过 gem 安装\n"
                let verifyResult = Shell.run("fastlane --version 2>/dev/null | tail -1")
                if verifyResult.code == 0 && !verifyResult.out.isEmpty {
                    log += "✅ 验证成功: \(verifyResult.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
                    return true
                }
            }
            
            // 尝试安装（如果指定版本，使用指定版本；否则安装最新版本）
            let gemCommand = version == "latest" || version.isEmpty 
                ? "gem install fastlane -NV" 
                : "gem install fastlane -v \(version) -NV"
            log += "   执行命令: \(gemCommand)\n"
            let gemInstallResult = Shell.run(gemCommand, timeout: 600)
            log += gemInstallResult.out
            if !gemInstallResult.err.isEmpty {
                log += "\n⚠️ Gem 安装警告:\n\(gemInstallResult.err)"
            }
            
            if gemInstallResult.code == 0 {
                log += "\n✅ Gem 安装成功！\n"
                // 验证安装
                let verifyResult = Shell.run("fastlane --version 2>/dev/null | tail -1")
                if verifyResult.code == 0 && !verifyResult.out.isEmpty {
                    log += "✅ 验证成功: \(verifyResult.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
                    return true
                } else {
                    log += "⚠️ 安装成功但验证失败，请手动检查\n"
                }
            } else {
                log += "\n⚠️ Gem 安装失败\n"
            }
        } else {
            log += "⚠️ Ruby 不可用，跳过此方法\n"
        }
        
        // 方法4: 所有方法都失败
        log += "\n❌ 所有安装方法均失败\n"
        log += "💡 建议:\n"
        log += "   1. 检查错误日志中的具体错误信息\n"
        log += "   2. 尝试手动安装:\n"
        log += "      - Homebrew: brew install fastlane\n"
        log += "      - Gem: gem install fastlane -NV\n"
        log += "      - asdf: asdf plugin add fastlane https://github.com/jonathanmorley/asdf-fastlane.git && asdf install fastlane \(version)\n"
        log += "   3. 确保 Ruby 已正确安装（gem 安装需要 Ruby）\n"
        log += "   4. 查看 Fastlane 官方文档: https://docs.fastlane.tools/getting-started/ios/setup/\n"
        
        return false
    }
    
    func refreshInstalledVersions(language: ProgrammingLanguage) {
        guard let index = languages.firstIndex(where: { $0.id == language.id }) else { return }
        refreshLanguageStatus(at: index)
    }
    
    /// 删除语言（从列表中移除）
    func removeLanguage(_ language: ProgrammingLanguage) {
        guard let index = languages.firstIndex(where: { $0.id == language.id }) else { return }
        languages.remove(at: index)
        print("🗑️ [DEBUG] 已删除语言: \(language.id)")
    }
    
    func loadAvailableVersions(language: ProgrammingLanguage) {
        let languageId = language.id
        
        // 检查是否已经在加载这个语言的版本列表
        if loadingVersionsForLanguageId == languageId {
            print("⚠️ [DEBUG] 语言 \(languageId) 的版本列表正在加载中，跳过重复请求")
            return
        }
        
        guard let index = languages.firstIndex(where: { $0.id == languageId }) else {
            print("⚠️ [DEBUG] 找不到语言: \(languageId)")
            return
        }
        
        // 设置加载状态
        loadingVersionsForLanguageId = languageId
        
        // 1. 立即显示预置版本（提升用户体验）
        let predefinedVersions = SoftConfig.getPredefinedVersions(for: languageId)
        DispatchQueue.main.async {
            // 使用语言ID验证，而不是索引（因为索引可能在异步任务执行期间改变）
            guard let currentIndex = self.languages.firstIndex(where: { $0.id == languageId }),
                  currentIndex < self.languages.count else {
                print("⚠️ [DEBUG] 语言 \(languageId) 已不存在，取消加载")
                self.loadingVersionsForLanguageId = nil
                return
            }
            
            self.languages[currentIndex].availableVersions = predefinedVersions
            // 触发视图更新
            self.objectWillChange.send()
            
            print("📋 [DEBUG] 立即显示预置版本: \(languageId), 共 \(predefinedVersions.count) 个版本")
        }
        
        // 2. 后台加载完整版本列表
        DispatchQueue.global(qos: .userInitiated).async {
            // 在异步任务开始时验证语言ID是否仍然匹配（防止在进入异步任务前语言已切换）
            guard self.loadingVersionsForLanguageId == languageId else {
                print("⚠️ [DEBUG] 异步任务开始前语言已切换，取消加载: \(languageId)")
                return
            }
            
            // 对于不同语言，使用更高效的命令，只获取最近的版本
            let command: String
            let limit: Int
            let timeout: TimeInterval
            
            if languageId == "java" {
                // Java 版本列表非常长，使用 head 只获取最新的版本，避免遍历整个列表
                command = "asdf list all \(languageId) 2>/dev/null | grep -E '^(temurin|adopt|zulu|corretto|openjdk)' | head -50"
                limit = 50
                timeout = 8
            } else if languageId == "rust" {
                // Rust 版本列表也很长，且加载很慢，只获取最新的版本
                // 使用 tail -30 获取最新版本，速度更快
                command = "asdf list all \(languageId) 2>/dev/null | tail -30"
                limit = 30
                timeout = 10  // Rust 加载可能较慢，但限制为 10 秒
            } else if languageId == "kotlin" {
                // Kotlin 版本列表可能也很长，限制获取数量
                command = "asdf list all \(languageId) 2>/dev/null | tail -50"
                limit = 50
                timeout = 10  // Kotlin 也设置较短超时
            } else if languageId == "php" {
                // PHP 版本列表加载可能很慢，优先获取稳定版本（8.x 和 7.x 系列）
                // 使用 grep 过滤主要版本系列，然后取最新的版本
                command = "asdf list all \(languageId) 2>/dev/null | grep -E '^(8\\.|7\\.|5\\.)' | tail -60"
                limit = 60
                timeout = 15  // PHP 可能需要更长时间来获取版本列表
            } else if languageId == "fastlane" {
                // fastlane 版本列表可能比较长，使用更高效的方法
                // 先尝试获取最新版本，如果失败则直接使用预置版本
                command = "asdf list all \(languageId) 2>/dev/null | tail -30"
                limit = 30
                timeout = 8  // 减少超时时间，如果超时直接使用预置版本
            } else {
                command = "asdf list all \(languageId) 2>/dev/null | tail -50"
                limit = 50
                timeout = 12
            }
            
            let result = Shell.run(command, timeout: timeout)
            var loadedVersions = VersionManager.cleanVersionOutput(result.out)
            
            // 如果命令超时或失败，使用备用方法（仅获取最后几个版本）
            if loadedVersions.isEmpty || result.code != 0 {
                print("⚠️ [DEBUG] 加载版本列表超时或失败，使用备用方法: \(languageId)")
                
                // PHP 的特殊备用方法：直接使用预置版本，不尝试再次加载
                if languageId == "php" {
                    print("📋 [DEBUG] PHP 版本列表加载失败，仅使用预置版本")
                    // 不设置 loadedVersions，让它保持为空，后续只使用预置版本
                    loadedVersions = []
                } else if languageId == "npm" {
                    // npm 通常随 Node.js 一起安装，可能没有独立的版本列表
                    print("📋 [DEBUG] npm 版本列表加载失败，npm 通常随 Node.js 一起安装")
                    loadedVersions = []
                } else if languageId == "fastlane" {
                    // fastlane 版本列表加载可能很慢，直接使用预置版本，不尝试再次加载
                    print("📋 [DEBUG] fastlane 版本列表加载失败，仅使用预置版本")
                    loadedVersions = []
                } else {
                    let fallbackCommand = "asdf list all \(languageId) 2>/dev/null | tail -20"
                    let fallbackResult = Shell.run(fallbackCommand, timeout: 5)
                    loadedVersions = VersionManager.cleanVersionOutput(fallbackResult.out)
                }
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
                // 关键修复：使用语言ID验证，而不是索引
                // 因为如果在异步任务执行期间用户切换了语言，索引可能仍然有效但对应的语言ID已经改变了
                guard let currentIndex = self.languages.firstIndex(where: { $0.id == languageId }),
                      currentIndex < self.languages.count else {
                    print("⚠️ [DEBUG] 语言 \(languageId) 已不存在或已切换，取消更新版本列表")
                    self.loadingVersionsForLanguageId = nil
                    return
                }
                
                // 验证当前加载的语言ID是否仍然匹配（防止在加载过程中切换了语言）
                if self.loadingVersionsForLanguageId != languageId {
                    print("⚠️ [DEBUG] 语言已切换（从 \(languageId) 切换），取消更新版本列表")
                    return
                }
                
                // 更新版本列表
                self.languages[currentIndex].availableVersions = mergedVersions
                
                // 清除加载状态
                self.loadingVersionsForLanguageId = nil
                
                // 强制触发 SwiftUI 视图更新
                self.objectWillChange.send()
                
                print("✅ [DEBUG] 合并版本列表完成并已刷新: \(languageId), 预置 \(predefinedVersions.count) 个, 加载 \(loadedVersions.count) 个, 合并后共 \(mergedVersions.count) 个版本")
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
            var log = ""
            var success = false
            var tip = ""
            
            // 1. 确保插件已添加
            let pluginCheck = Shell.run("asdf plugin list | grep -w '\(language.id)'")
            if pluginCheck.code != 0 {
                log += "📦 添加 asdf 插件...\n"
                
                // PHP 特殊处理：使用正确的插件 URL
                let pluginAddCommand: String
                if language.id == "php" {
                    pluginAddCommand = "asdf plugin add php https://github.com/asdf-community/asdf-php.git"
                } else {
                    pluginAddCommand = "asdf plugin add \(language.id)"
                }
                
                let pluginResult = Shell.run(pluginAddCommand)
                if pluginResult.code != 0 {
                    log += "❌ 插件添加失败: \(pluginResult.err)\n"
                    log += pluginResult.out
                    
                    // PHP 特殊处理：提供更详细的错误信息
                    if language.id == "php" {
                        log += "\n💡 提示: PHP 插件添加失败。\n"
                        log += "   请手动运行: asdf plugin add php https://github.com/asdf-community/asdf-php.git\n"
                        log += "   或检查网络连接和 asdf 配置。\n"
                    }
                    
                    tip = "插件添加失败，请检查网络连接或手动添加插件。"
                    DispatchQueue.main.async {
                        completion(false, log, tip)
                    }
                    return
                }
                log += "✅ 插件已添加\n"
            } else {
                log += "✅ 插件已就绪\n"
            }
            
            // 2. PHP 特殊处理：检查并自动安装依赖项
            if language.id == "php" {
                log += "🔍 检查 PHP 安装依赖...\n"
                let dependencies = ["autoconf", "pkg-config", "libxml2", "openssl"]
                var missingDeps: [String] = []
                
                // 检查每个依赖是否已安装
                for dep in dependencies {
                    // 检查是否在 PATH 中或通过 Homebrew 安装
                    let checkResult = Shell.run("which \(dep) 2>/dev/null || brew list --formula \(dep) 2>/dev/null | head -1")
                    if checkResult.code != 0 {
                        missingDeps.append(dep)
                    }
                }
                
                if !missingDeps.isEmpty {
                    log += "⚠️ 缺少以下依赖: \(missingDeps.joined(separator: ", "))\n"
                    log += "📦 自动安装缺失的依赖...\n"
                    
                    // 检查 Homebrew 是否可用
                    let brewCheck = Shell.run("which brew")
                    if brewCheck.code == 0 {
                        // 自动安装缺失的依赖
                        let installDepsCommand = "brew install \(missingDeps.joined(separator: " "))"
                        log += "   执行命令: \(installDepsCommand)\n"
                        
                        let installDepsResult = Shell.run(installDepsCommand, timeout: 300) // 依赖安装可能需要较长时间
                        log += installDepsResult.out
                        if !installDepsResult.err.isEmpty {
                            log += "\n⚠️ 依赖安装警告:\n\(installDepsResult.err)"
                        }
                        
                        if installDepsResult.code == 0 {
                            log += "\n✅ 依赖安装成功\n"
                        } else {
                            log += "\n⚠️ 部分依赖可能安装失败，将继续尝试安装 PHP...\n"
                        }
                    } else {
                        log += "❌ Homebrew 未找到，无法自动安装依赖\n"
                        log += "💡 请先安装 Homebrew，然后运行: brew install \(missingDeps.joined(separator: " "))\n"
                    }
                } else {
                    log += "✅ 依赖检查通过\n"
                }
            }
            
            // 3. 安装版本 - 使用多种安装方式回退机制（仅对 PHP 和 fastlane）
            var installResult: (code: Int32, out: String, err: String)? = nil
            if language.id == "php" {
                success = self.installPhpWithFallback(version: version, log: &log)
            } else if language.id == "fastlane" {
                success = self.installFastlaneWithFallback(version: version, log: &log)
            } else {
                // 其他语言使用标准 asdf 安装
                log += "📥 开始安装 \(language.id) \(version)...\n"
                installResult = Shell.run("asdf install \(language.id) \(version)", timeout: 600)
                log += installResult!.out
                if !installResult!.err.isEmpty {
                    log += "\n⚠️ 错误输出:\n\(installResult!.err)"
                }
                success = installResult!.code == 0
            }
            
            // 4. 验证安装是否成功
            if success {
                log += "\n✅ 安装完成，验证中...\n"
                
                // PHP 特殊验证：需要检查 asdf 和 Homebrew 两种安装方式
                if language.id == "php" {
                    var verified = false
                    
                    // 检查 asdf 安装
                    let asdfVerifyResult = Shell.run("asdf list php 2>/dev/null | grep -w '\(version)'")
                    if asdfVerifyResult.code == 0 && !asdfVerifyResult.out.isEmpty {
                        log += "✅ asdf 版本验证成功: \(version) 已安装\n"
                        verified = true
                        
                        // 验证可执行文件
                        let phpPathResult = Shell.run("asdf where php \(version) 2>/dev/null")
                        if phpPathResult.code == 0 {
                            let phpPath = phpPathResult.out.trimmingCharacters(in: .whitespacesAndNewlines)
                            let phpBinPath = "\(phpPath)/bin/php"
                            let phpCheck = Shell.run("test -f '\(phpBinPath)' && '\(phpBinPath)' --version 2>/dev/null | head -1")
                            if phpCheck.code == 0 {
                                log += "✅ PHP 可执行文件验证成功\n"
                                log += "   \(phpCheck.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
                            }
                        }
                    }
                    
                    // 检查 Homebrew 安装
                    if !verified {
                        let brewVersion = self.extractBrewPhpVersion(from: version)
                        if let brewVersion = brewVersion {
                            // 检查 Homebrew PHP 路径（多种可能的路径）
                            let homebrewPhpPaths = [
                                "/opt/homebrew/opt/php@\(brewVersion)/bin/php",
                                "/usr/local/opt/php@\(brewVersion)/bin/php",
                                "/opt/homebrew/bin/php",  // 如果已链接
                                "/usr/local/bin/php"      // 如果已链接
                            ]
                            
                            var foundPhpPath: String? = nil
                            var foundVersion: String? = nil
                            
                            for phpPath in homebrewPhpPaths {
                                let phpCheck = Shell.run("test -f '\(phpPath)' && '\(phpPath)' --version 2>/dev/null | head -1")
                                if phpCheck.code == 0 {
                                    let output = phpCheck.out.trimmingCharacters(in: .whitespacesAndNewlines)
                                    
                                    // 提取版本号
                                    if let versionMatch = output.range(of: #"PHP (\d+\.\d+\.\d+)"#, options: .regularExpression) {
                                        let fullMatch = String(output[versionMatch])
                                        foundVersion = fullMatch.replacingOccurrences(of: "PHP ", with: "")
                                        
                                        // 检查是否匹配请求的版本（允许主次版本匹配，如 8.3.x 都算匹配）
                                        if foundVersion!.hasPrefix(brewVersion) {
                                            foundPhpPath = phpPath
                                            break
                                        }
                                    } else if let simpleMatch = output.range(of: #"PHP (\d+\.\d+)"#, options: .regularExpression) {
                                        let fullMatch = String(output[simpleMatch])
                                        let simpleVersion = fullMatch.replacingOccurrences(of: "PHP ", with: "")
                                        
                                        // 检查主次版本是否匹配
                                        if simpleVersion == brewVersion {
                                            foundPhpPath = phpPath
                                            foundVersion = version // 使用请求的完整版本号
                                            break
                                        }
                                    }
                                }
                            }
                            
                            // 如果没找到，尝试通过 brew list 检查
                            if foundPhpPath == nil {
                                let brewListCheck = Shell.run("brew list --formula php@\(brewVersion) 2>/dev/null || brew list php@\(brewVersion) 2>/dev/null | head -1")
                                if brewListCheck.code == 0 {
                                    // 找到了，但路径可能不同，尝试通过 brew --prefix 获取
                                    let prefixResult = Shell.run("brew --prefix php@\(brewVersion) 2>/dev/null")
                                    if prefixResult.code == 0 {
                                        let prefix = prefixResult.out.trimmingCharacters(in: .whitespacesAndNewlines)
                                        let possiblePath = "\(prefix)/bin/php"
                                        let finalCheck = Shell.run("test -f '\(possiblePath)' && '\(possiblePath)' --version 2>/dev/null | head -1")
                                        if finalCheck.code == 0 {
                                            foundPhpPath = possiblePath
                                            foundVersion = version
                                        }
                                    }
                                }
                            }
                            
                            if let phpPath = foundPhpPath, let detectedVersion = foundVersion {
                                log += "✅ Homebrew PHP 版本验证成功: \(detectedVersion) (通过 php@\(brewVersion))\n"
                                log += "   路径: \(phpPath)\n"
                                
                                // 尝试将 Homebrew 版本链接到 asdf（可选，但推荐）
                                let asdfInstallPath = FileManager.default.homeDirectoryForCurrentUser.path + "/.asdf/installs/php/\(version)"
                                let linkPath = phpPath.replacingOccurrences(of: "/bin/php", with: "")
                                
                                // 检查是否已存在链接
                                let linkCheck = Shell.run("test -L '\(asdfInstallPath)' || test -d '\(asdfInstallPath)'")
                                if linkCheck.code != 0 {
                                    log += "\n💡 提示: 可以将 Homebrew 版本链接到 asdf 管理:\n"
                                    log += "   mkdir -p ~/.asdf/installs/php\n"
                                    log += "   ln -s \(linkPath) ~/.asdf/installs/php/\(version)\n"
                                }
                                
                                verified = true
                            }
                        }
                    }
                    
                    if verified {
                        tip = "安装成功！使用 '设为全局' 按钮来启用此版本。"
                    } else {
                        log += "⚠️ 版本验证失败: 安装可能未完全成功\n"
                        success = false
                        tip = "安装可能未完全成功，请检查日志或手动验证。"
                    }
                } else if language.id == "fastlane" {
                    // Fastlane 验证：检查所有可能的安装方式
                    var verified = false
                    
                    // 检查 asdf 安装
                    let asdfVerifyResult = Shell.run("asdf list fastlane 2>/dev/null | grep -w '\(version)'")
                    if asdfVerifyResult.code == 0 && !asdfVerifyResult.out.isEmpty {
                        log += "✅ asdf 版本验证成功: \(version) 已安装\n"
                        verified = true
                    }
                    
                    // 检查 Homebrew 安装
                    if !verified {
                        let brewCheck = Shell.run("brew list --formula fastlane 2>/dev/null | head -1")
                        if brewCheck.code == 0 {
                            let versionCheck = Shell.run("fastlane --version 2>/dev/null | tail -1")
                            if versionCheck.code == 0 && !versionCheck.out.isEmpty {
                                log += "✅ Homebrew Fastlane 验证成功: \(versionCheck.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
                                verified = true
                            }
                        }
                    }
                    
                    // 检查 gem 安装
                    if !verified {
                        let gemCheck = Shell.run("gem list fastlane --local 2>/dev/null | grep fastlane")
                        if gemCheck.code == 0 && !gemCheck.out.isEmpty {
                            let versionCheck = Shell.run("fastlane --version 2>/dev/null | tail -1")
                            if versionCheck.code == 0 && !versionCheck.out.isEmpty {
                                log += "✅ Gem Fastlane 验证成功: \(versionCheck.out.trimmingCharacters(in: .whitespacesAndNewlines))\n"
                                verified = true
                            }
                        }
                    }
                    
                    if verified {
                        tip = "安装成功！Fastlane 已可用。"
                    } else {
                        log += "⚠️ 版本验证失败: 安装可能未完全成功\n"
                        success = false
                        tip = "安装可能未完全成功，请检查日志或手动验证。"
                    }
                } else {
                    // 其他语言的验证
                    let verifyResult = Shell.run("asdf list \(language.id) 2>/dev/null | grep -w '\(version)'")
                    if verifyResult.code == 0 && !verifyResult.out.isEmpty {
                        log += "✅ 版本验证成功: \(version) 已安装\n"
                        tip = "安装成功！使用 '设为全局' 按钮来启用此版本。"
                    } else {
                        log += "⚠️ 版本验证失败: 安装可能未完全成功\n"
                        success = false
                        tip = "安装可能未完全成功，请检查日志或手动验证。"
                    }
                }
            } else {
                tip = "安装失败。"
                
                // PHP 的错误处理已经在 installPhpWithFallback 方法中完成
                if language.id == "php" {
                    // PHP 的错误信息已经在 log 中详细记录，这里只提供简短提示
                    tip += " 详细错误信息请查看上方日志。"
                } else if language.id == "fastlane" {
                    // Fastlane 的错误处理已经在 installFastlaneWithFallback 方法中完成
                    tip += " 详细错误信息请查看上方日志。"
                } else if let result = installResult {
                    // 其他语言的错误提示
                    if result.err.contains("not found") || result.err.contains("No versions") {
                        tip += " 版本号可能不正确，请检查可用版本列表。"
                    } else {
                        tip += " 请检查错误日志获取详细信息。"
                    }
                } else {
                    tip += " 请检查版本号是否正确。"
                }
            }
            
            DispatchQueue.main.async {
                completion(success, log, tip)
                
                // 5. 如果安装成功，刷新语言状态
                if success {
                    // 延迟刷新，确保文件系统更新完成
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if let index = self.languages.firstIndex(where: { $0.id == language.id }) {
                            self.refreshLanguageStatus(at: index)
                        }
                    }
                }
            }
        }
    }
    
    func setGlobalVersion(language: ProgrammingLanguage, version: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // 1. 确保 asdf 插件已添加
            let pluginCheck = Shell.run("asdf plugin list | grep -w '\(language.id)'")
            if pluginCheck.code != 0 {
                // PHP 特殊处理：使用正确的插件 URL
                let pluginAddCommand: String
                if language.id == "php" {
                    pluginAddCommand = "asdf plugin add php https://github.com/asdf-community/asdf-php.git"
                } else {
                    pluginAddCommand = "asdf plugin add \(language.id)"
                }
                
                let addPluginResult = Shell.run(pluginAddCommand)
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
                
            case "gradle":
                // Gradle 系统安装路径
                if executablePath.contains("/usr/local/bin/gradle") {
                    return "/usr/local"
                } else if executablePath.contains("/opt/homebrew") {
                    let path = executablePath as NSString
                    let binPath = path.deletingLastPathComponent
                    let gradlePath = (binPath as NSString).deletingLastPathComponent
                    return gradlePath
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
            
        case "gradle":
            // Gradle 需要设置 GRADLE_HOME
            envVars["GRADLE_HOME"] = installPath
            envVars["PATH"] = "$GRADLE_HOME/bin:$PATH"
            
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
        // 这个方法保留用于兼容性，但实际显示逻辑在LanguageDetailView中处理
    }
}

// 版本详情视图
struct VersionDetailView: View {
    let detailInfo: LanguageDetailView.VersionDetailInfo
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 标题部分
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(detailInfo.language.color.opacity(0.2))
                                    .frame(width: 48, height: 48)
                                
                                Image(systemName: detailInfo.language.icon)
                                    .font(.system(size: 24))
                                    .foregroundColor(detailInfo.language.color)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(detailInfo.language.displayName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("\(tr("Version:")) \(detailInfo.version)")
                                    .font(.title3)
                                    .fontWeight(.medium)
                            }
                            
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                    
                    // 基本信息
                    VStack(alignment: .leading, spacing: 12) {
                        Text(tr("Basic Information"))
                            .font(.headline)
                            .padding(.bottom, 4)
                        
                        DetailRow(label: tr("Version Source"), value: detailInfo.versionSource.displayName)
                        DetailRow(label: tr("Current Version"), value: detailInfo.version)
                        
                        if let asdfGlobal = detailInfo.asdfGlobalVersion {
                            DetailRow(label: tr("asdf Global Version"), value: asdfGlobal)
                            if asdfGlobal != detailInfo.version {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    Text(tr("asdf global configuration differs from current version"))
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                    
                    // 路径信息
                    VStack(alignment: .leading, spacing: 12) {
                        Text(tr("Path Information"))
                            .font(.headline)
                            .padding(.bottom, 4)
                        
                        if let versionPath = detailInfo.versionPath {
                            DetailRow(label: tr("Version Path"), value: versionPath, isPath: true)
                        } else {
                            DetailRow(label: tr("Version Path"), value: tr("Not available"))
                        }
                        
                        if let execPath = detailInfo.executablePath {
                            DetailRow(label: tr("Executable Path"), value: execPath, isPath: true)
                        } else {
                            DetailRow(label: tr("Executable Path"), value: tr("Not found in PATH"))
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                    
                    // 已安装版本列表
                    VStack(alignment: .leading, spacing: 12) {
                        Text(tr("Installed Versions"))
                            .font(.headline)
                            .padding(.bottom, 4)
                        
                        if detailInfo.allInstalledVersions.isEmpty {
                            Text(tr("No versions installed"))
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(tr("Total:")) \(detailInfo.allInstalledVersions.count) \(tr("versions"))")
                                    .font(.subheadline)
                                
                                if !detailInfo.asdfInstalledVersions.isEmpty {
                                    Text("\(tr("asdf versions:")) \(detailInfo.asdfInstalledVersions.count)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                // 显示版本列表
                                LazyVStack(alignment: .leading, spacing: 6) {
                                    ForEach(detailInfo.allInstalledVersions, id: \.self) { version in
                                        HStack {
                                            Text(version)
                                                .font(.system(.body, design: .monospaced))
                                            if version == detailInfo.version {
                                                Text(tr("(Current)"))
                                                    .font(.caption)
                                                    .foregroundColor(.green)
                                                    .fontWeight(.medium)
                                            }
                                            if detailInfo.asdfInstalledVersions.contains(version) {
                                                Spacer()
                                                Text("asdf")
                                                    .font(.caption2)
                                                    .foregroundColor(.blue)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.blue.opacity(0.1))
                                                    .cornerRadius(4)
                                            }
                                        }
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .background(Color.secondary.opacity(0.05))
                                        .cornerRadius(6)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(NSColor.windowBackgroundColor))
            .frame(minWidth: 600, minHeight: 500)
            .navigationTitle(tr("Version Details"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Close")) {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 650, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// 详情行组件
struct DetailRow: View {
    let label: String
    let value: String
    var isPath: Bool = false
    @State private var copied: Bool = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .leading)
            
            if isPath {
                HStack(spacing: 8) {
                    Text(value)
                        .font(.system(.subheadline, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Button(action: {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(value, forType: .string)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            copied = false
                        }
                    }) {
                        Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                            .foregroundColor(copied ? .green : .blue)
                            .font(.caption)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(tr("Copy to Clipboard"))
                }
            } else {
                Text(value)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 4)
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
        
        // 1. 立即显示预置插件列表（提升用户体验）
        let predefinedPlugins = SoftConfig.getPredefinedAsdfPlugins()
        let predefinedAsdfPlugins = predefinedPlugins.map { plugin in
            AsdfPlugin(
                name: plugin.name,
                url: plugin.url,
                description: plugin.description
            )
        }
        
        DispatchQueue.main.async {
            // 过滤掉已经添加的语言
            let existingLanguageIds = Set(self.viewModel.languages.map { $0.id })
            self.availablePlugins = predefinedAsdfPlugins.filter { !existingLanguageIds.contains($0.name) }
            self.isLoading = false
            
            print("📋 [DEBUG] 立即显示预置插件: \(self.availablePlugins.count) 个")
        }
        
        // 2. 后台异步加载完整的插件列表（可选，用于获取更多插件）
        DispatchQueue.global(qos: .utility).async {
            // 获取所有可用的 asdf 插件
            let result = Shell.run("asdf plugin list all", timeout: 15)
            
            var loadedPlugins: [AsdfPlugin] = []
            
            if result.code == 0 && !result.out.isEmpty {
                let lines = result.out.components(separatedBy: "\n")
                
                for line in lines {
                    let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    if parts.count >= 2 {
                        let name = parts[0]
                        let url = parts[1]
                        loadedPlugins.append(AsdfPlugin(
                            name: name,
                            url: url,
                            description: self.getPluginDescription(name)
                        ))
                    }
                }
            }
            
            // 合并预置和加载的插件，去重
            if !loadedPlugins.isEmpty {
            DispatchQueue.main.async {
                    let existingLanguageIds = Set(self.viewModel.languages.map { $0.id })
                    let existingPluginNames = Set(self.availablePlugins.map { $0.name })
                    
                    // 只添加不在预置列表和已添加语言中的插件
                    let newPlugins = loadedPlugins.filter { plugin in
                        !existingLanguageIds.contains(plugin.name) && 
                        !existingPluginNames.contains(plugin.name)
                    }
                    
                    // 合并并排序
                    var mergedPlugins = self.availablePlugins
                    mergedPlugins.append(contentsOf: newPlugins)
                    mergedPlugins = mergedPlugins.sorted { $0.name < $1.name }
                    
                    self.availablePlugins = mergedPlugins
                    
                    print("✅ [DEBUG] 合并后的插件列表: \(self.availablePlugins.count) 个（预置: \(predefinedAsdfPlugins.count), 新增: \(newPlugins.count)）")
                }
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
            "r": "r.circle.fill",
            "gradle": "hammer.fill"
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
            "r": .blue,
            "gradle": .green
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
