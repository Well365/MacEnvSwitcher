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
                    
                    if let currentVersion = language.currentVersion {
                        HStack {
                            Text(currentVersion)
                                .font(.title3)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Button("查看详情") {
                                viewModel.showVersionDetails(language: language, version: currentVersion)
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
                            viewModel.refreshInstalledVersions(language: language)
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    
                    if language.installedVersions.isEmpty {
                        Text("尚未安装任何版本")
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(language.installedVersions, id: \.self) { version in
                                InstalledVersionRow(
                                    version: version,
                                    isCurrent: version == language.currentVersion,
                                    onSetGlobal: {
                                        viewModel.setGlobalVersion(language: language, version: version)
                                    },
                                    onUninstall: {
                                        viewModel.uninstallVersion(language: language, version: version)
                                    }
                                )
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
                                    viewModel.loadAvailableVersions(language: language)
                                }
                                .font(.caption)
                            }
                            
                            if language.availableVersions.isEmpty {
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
                                    ForEach(language.availableVersions, id: \.self) { version in
                                        Text(version).tag(version)
                                    }
                                }
                                .labelsHidden()
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
        .onAppear {
            viewModel.loadAvailableVersions(language: language)
        }
    }
    
    private var canInstall: Bool {
        if viewModel.versionSelectionMode == .fromList {
            return !selectedVersion.isEmpty
        } else {
            return !customVersionInput.isEmpty
        }
    }
    
    private func installVersion(_ version: String) {
        isInstalling = true
        installLog = "开始安装 \(language.displayName) \(version)...\n"
        
        viewModel.installVersion(language: language, version: version) { success, log, tip in
            installLog += log
            if let tip = tip {
                installLog += "\n\n💡 提示: \(tip)"
            }
            isInstalling = false
            
            if success {
                // 刷新已安装版本列表
                viewModel.refreshInstalledVersions(language: language)
            }
        }
    }
}

// 已安装版本行
struct InstalledVersionRow: View {
    let version: String
    let isCurrent: Bool
    let onSetGlobal: () -> Void
    let onUninstall: () -> Void
    
    @State private var showingUninstallAlert = false
    
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
            
            Spacer()
            
            if !isCurrent {
                Button("设为全局") {
                    onSetGlobal()
                }
                .font(.caption)
            }
            
            Button(action: {
                showingUninstallAlert = true
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
            .alert("确认卸载", isPresented: $showingUninstallAlert) {
                Button("取消", role: .cancel) { }
                Button("卸载", role: .destructive) {
                    onUninstall()
                }
            } message: {
                Text("确定要卸载版本 \(version) 吗？")
            }
        }
        .padding()
        .background(isCurrent ? Color.green.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// 编程语言数据模型
struct ProgrammingLanguage: Identifiable {
    let id: String
    let displayName: String
    let description: String
    let icon: String
    let color: Color
    var isInstalled: Bool
    var currentVersion: String?
    var installedVersions: [String]
    var availableVersions: [String]
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
    
    func refreshLanguageStatus(at index: Int) {
        let language = languages[index]
        
        DispatchQueue.global(qos: .userInitiated).async {
            // 检查是否安装
            let checkResult = Shell.run("asdf plugin list | grep -w '\(language.id)'")
            let isInstalled = checkResult.code == 0
            
            // 获取当前版本
            let currentResult = Shell.run("asdf current \(language.id) 2>/dev/null")
            let currentVersion: String? = {
                if currentResult.code == 0 {
                    let components = currentResult.out.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .whitespaces)
                    return components.count >= 2 ? components[1] : nil
                }
                return nil
            }()
            
            // 获取已安装版本
            let installedResult = Shell.run("asdf list \(language.id) 2>/dev/null")
            let installedVersions = VersionManager.cleanVersionOutput(installedResult.out)
            
            DispatchQueue.main.async {
                self.languages[index].isInstalled = isInstalled
                self.languages[index].currentVersion = currentVersion
                self.languages[index].installedVersions = installedVersions
            }
        }
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
    
    func setGlobalVersion(language: ProgrammingLanguage, version: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Shell.run("asdf global \(language.id) \(version) && asdf reshim \(language.id)")
            
            if result.code == 0 {
                // 刷新状态
                if let index = self.languages.firstIndex(where: { $0.id == language.id }) {
                    self.refreshLanguageStatus(at: index)
                }
            }
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
