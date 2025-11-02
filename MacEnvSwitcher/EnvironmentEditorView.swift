import SwiftUI

struct EnvironmentEditorView: View {
    @Binding var isPresented: Bool
    @Binding var profile: EnvironmentProfile
    let isNew: Bool
    let onSave: (EnvironmentProfile) -> Void
    
    @State private var editedProfile: EnvironmentProfile
    @State private var showVersionEditor = false
    @State private var showVirtualEnvEditor = false
    @State private var showEnvVarEditor = false
    @State private var selectedLanguage = ""
    @State private var selectedVersion = ""
    @State private var selectedVirtualEnv = VirtualEnvironment(type: .pythonVenv, name: "")
    @State private var selectedEnvKey = ""
    @State private var selectedEnvValue = ""
    
    init(isPresented: Binding<Bool>, profile: Binding<EnvironmentProfile>, isNew: Bool, onSave: @escaping (EnvironmentProfile) -> Void) {
        self._isPresented = isPresented
        self._profile = profile
        self.isNew = isNew
        self.onSave = onSave
        self._editedProfile = State(initialValue: profile.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Basic info section
                    VStack(alignment: .leading, spacing: 16) {
                        Text(tr("Basic Information"))
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text(tr("Environment Name"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField(tr("Enter environment name"), text: $editedProfile.name)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text(tr("Description (Optional)"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            if #available(macOS 13.0, *) {
                                TextField(tr("Enter description"), text: $editedProfile.description, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(3...6)
                            } else {
                                TextField(tr("Enter description"), text: $editedProfile.description)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                    
                    // Language versions section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(tr("Language Versions"))
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        
                        if editedProfile.versions.isEmpty {
                            Text(tr("No language versions added"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(editedProfile.versions.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                    HStack(spacing: 12) {
                                        Text(key)
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .frame(width: 120, alignment: .leading)
                                        
                                        TextField("Version", text: Binding(
                                            get: { editedProfile.versions[key] ?? "" },
                                            set: { editedProfile.versions[key] = $0 }
                                        ))
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(.body, design: .monospaced))
                                        
                                        Button(action: {
                                            selectedLanguage = key
                                            selectedVersion = editedProfile.versions[key] ?? ""
                                            showVersionEditor = true
                                        }) {
                                            Image(systemName: "pencil.circle.fill")
                                                .foregroundColor(.blue)
                                        }
                                        .buttonStyle(.plain)
                                        .help(tr("Edit Version"))
                                        
                                        Button(action: {
                                            editedProfile.versions.removeValue(forKey: key)
                                        }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(.red)
                                        }
                                        .buttonStyle(.plain)
                                        .help(tr("Remove"))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Color(NSColor.textBackgroundColor))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        
                        Button(action: {
                            selectedLanguage = ""
                            selectedVersion = ""
                            showVersionEditor = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text(tr("Add Language Version"))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                    
                    // Virtual environments section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(tr("Virtual Environments"))
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        
                        if editedProfile.virtualEnvs.isEmpty {
                            Text(tr("No virtual environments added"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(editedProfile.virtualEnvs.sorted(by: { $0.key < $1.key }), id: \.key) { key, venv in
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(key)
                                                .font(.body)
                                                .fontWeight(.medium)
                                            Spacer()
                                            Button(action: {
                                                editedProfile.virtualEnvs.removeValue(forKey: key)
                                            }) {
                                                Image(systemName: "minus.circle.fill")
                                                    .foregroundColor(.red)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        Text("\(venv.type.displayName): \(venv.name)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Color(NSColor.textBackgroundColor))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        
                        Button(action: {
                            selectedLanguage = ""
                            selectedVirtualEnv = VirtualEnvironment(type: .pythonVenv, name: "")
                            showVirtualEnvEditor = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text(tr("Add Virtual Environment"))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                    
                    // Environment variables section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(tr("Environment Variables"))
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        
                        if editedProfile.environmentVars.isEmpty {
                            Text(tr("No environment variables added"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(Array(editedProfile.environmentVars.keys.sorted()), id: \.self) { key in
                                    EnvironmentVariableRow(
                                        key: key,
                                        value: Binding(
                                            get: { editedProfile.environmentVars[key] ?? "" },
                                            set: { editedProfile.environmentVars[key] = $0 }
                                        ),
                                        onKeyChange: { oldKey, newKey in
                                            if oldKey != newKey && !newKey.isEmpty {
                                                let oldValue = editedProfile.environmentVars[oldKey] ?? ""
                                                editedProfile.environmentVars.removeValue(forKey: oldKey)
                                                editedProfile.environmentVars[newKey] = oldValue
                                            }
                                        },
                                        onDelete: {
                                            editedProfile.environmentVars.removeValue(forKey: key)
                                        }
                                    )
                                }
                            }
                        }
                        
                        Button(action: {
                            selectedEnvKey = ""
                            selectedEnvValue = ""
                            showEnvVarEditor = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text(tr("Add Environment Variable"))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                }
                .padding(24)
            }
            .frame(minWidth: 900, idealWidth: 1000, minHeight: 700, idealHeight: 800)
            .navigationTitle(isNew ? tr("New Environment") : tr("Edit Environment"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Cancel")) {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(tr("Save")) {
                        if isNew {
                            editedProfile.createdAt = Date()
                        }
                        onSave(editedProfile)
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(editedProfile.name.isEmpty)
                }
            }
        }
        .frame(minWidth: 900, idealWidth: 1000, minHeight: 700, idealHeight: 800)
        .sheet(isPresented: $showVersionEditor) {
            VersionEditorSheet(
                isPresented: $showVersionEditor,
                language: $selectedLanguage,
                version: $selectedVersion,
                onSave: { lang, ver in
                    editedProfile.versions[lang] = ver
                }
            )
            .frame(minWidth: 600, idealWidth: 700, minHeight: 500, idealHeight: 600)
        }
        .sheet(isPresented: $showVirtualEnvEditor) {
            VirtualEnvEditorSheet(
                isPresented: $showVirtualEnvEditor,
                language: $selectedLanguage,
                virtualEnv: $selectedVirtualEnv,
                onSave: { lang, venv in
                    editedProfile.virtualEnvs[lang] = venv
                }
            )
            .frame(minWidth: 600, idealWidth: 700, minHeight: 500, idealHeight: 600)
        }
        .sheet(isPresented: $showEnvVarEditor) {
            EnvVarEditorSheet(
                isPresented: $showEnvVarEditor,
                key: $selectedEnvKey,
                value: $selectedEnvValue,
                onSave: { key, value in
                    editedProfile.environmentVars[key] = value
                }
            )
            .frame(minWidth: 600, idealWidth: 700, minHeight: 500, idealHeight: 600)
        }
    }
}

struct VersionEditorSheet: View {
    @Binding var isPresented: Bool
    @Binding var language: String
    @Binding var version: String
    let onSave: (String, String) -> Void
    
    @State private var isLoadingVersions: Bool = false
    @State private var availableVersions: [String] = []
    @State private var searchText: String = ""
    @State private var showCustomInput: Bool = false
    @State private var customLanguage: String = ""
    
    // 扩展的语言列表 - 包含更多常用语言和工具
    private let availableLanguages = [
        "nodejs", "python", "ruby", "java", "golang", "rust", 
        "gradle", "maven", "yarn", "pnpm", "npm",
        "php", "elixir", "kotlin", "scala", "dart", "lua", "r",
        "terraform", "vault", "consul", "nomad",
        "erlang", "haskell", "ocaml", "swift",
        "deno", "bun", "crystal", "nim", "zig"
    ]
    
    private var filteredLanguages: [String] {
        if searchText.isEmpty {
            return availableLanguages
        }
        return availableLanguages.filter { lang in
            lang.lowercased().contains(searchText.lowercased()) ||
            lang.capitalized.lowercased().contains(searchText.lowercased())
        }
    }
    
    // 预定义的常用版本
    private let predefinedVersions: [String: [String]] = [
        "nodejs": ["23.11.0", "20.9.0", "18.18.2", "16.20.2", "latest", "latest:lts"],
        "python": ["3.14.0", "3.12.0", "3.11.6", "3.10.13", "latest", "system"],
        "ruby": ["3.3.8", "3.2.0", "3.1.4", "2.7.6", "latest", "system"],
        "java": ["11.0.21", "8.0.432", "23.0.1", "17.0.9", "latest:temurin-11", "latest:temurin-17"],
        "golang": ["1.24.2", "1.21.4", "1.20.11", "latest", "system"],
        "gradle": ["7.6.1", "8.5", "8.4", "latest"],
        "rust": ["1.74.0", "1.73.0", "stable", "latest"],
        "maven": ["3.9.5", "3.8.8", "latest"],
        "yarn": ["1.22.19", "latest"],
        "pnpm": ["8.10.0", "latest"]
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Language Selection Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "terminal.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                            Text(tr("Language"))
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(tr("Select Language"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            // 搜索框
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                
                                TextField(tr("Search languages..."), text: $searchText)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body))
                                
                                if !searchText.isEmpty {
                                    Button(action: {
                                        searchText = ""
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            // 语言选择 - 使用列表而不是菜单
                            if filteredLanguages.isEmpty && !searchText.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.largeTitle)
                                        .foregroundColor(.secondary.opacity(0.5))
                                    Text(tr("No matching languages"))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    // 自定义输入选项
                                    Button(action: {
                                        showCustomInput = true
                                    }) {
                                        HStack {
                                            Image(systemName: "plus.circle.fill")
                                            Text(tr("Add Custom Language"))
                                        }
                                        .font(.subheadline)
                                    }
                                    .buttonStyle(.bordered)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 30)
                            } else {
                                // 语言列表
                                ScrollView {
                                    LazyVStack(spacing: 4) {
                                        ForEach(filteredLanguages, id: \.self) { lang in
                                            Button(action: {
                                                language = lang
                                                searchText = ""
                                            }) {
                                                HStack(spacing: 12) {
                                                    Text(getLanguageIcon(lang))
                                                        .font(.title3)
                                                    Text(lang.capitalized)
                                                        .font(.body)
                                                        .foregroundColor(.primary)
                                                    Spacer()
                                                    if language == lang {
                                                        Image(systemName: "checkmark")
                                                            .foregroundColor(.blue)
                                                    }
                                                }
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 10)
                                                .background(
                                                    language == lang 
                                                        ? Color.blue.opacity(0.1) 
                                                        : Color(NSColor.controlBackgroundColor)
                                                )
                                                .cornerRadius(8)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        
                                        // 自定义输入选项
                                        Divider()
                                            .padding(.vertical, 8)
                                        
                                        Button(action: {
                                            showCustomInput = true
                                        }) {
                                            HStack(spacing: 12) {
                                                Image(systemName: "plus.circle.fill")
                                                    .foregroundColor(.blue)
                                                Text(tr("Add Custom Language"))
                                                    .font(.body)
                                                    .foregroundColor(.blue)
                                                Spacer()
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(8)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .frame(maxHeight: 300)
                                .padding(4)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(10)
                            }
                        }
                        
                        if !language.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text("已选择: \(language)")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            .padding(.leading, 4)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Version Selection Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "number.circle.fill")
                                .foregroundColor(.orange)
                                .font(.title3)
                            Text(tr("Version"))
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        if language.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary.opacity(0.5))
                                Text(tr("Please select a language first"))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            // Version dropdown menu
                            VStack(alignment: .leading, spacing: 10) {
                                Text(tr("Select Version"))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Menu {
                                    ForEach(getVersionOptions(), id: \.self) { ver in
                                        Button(action: {
                                            version = ver
                                        }) {
                                            HStack {
                                                if ver == version {
                                                    Image(systemName: "checkmark")
                                                        .foregroundColor(.blue)
                                                }
                                                Text(ver)
                                            }
                                        }
                                    }
                                    
                                    Divider()
                                    
                                    Button(action: {
                                        loadAvailableVersions()
                                    }) {
                                        HStack {
                                            Image(systemName: "arrow.clockwise")
                                            Text(tr("Refresh Versions from asdf"))
                                            if isLoadingVersions {
                                                ProgressView()
                                                    .scaleEffect(0.6)
                                            }
                                        }
                                    }
                                } label: {
                                    HStack {
                                        if version.isEmpty {
                                            Image(systemName: "list.bullet")
                                                .foregroundColor(.secondary)
                                        } else {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                        }
                                        Text(version.isEmpty ? tr("Select Version") : version)
                                            .foregroundColor(version.isEmpty ? .secondary : .primary)
                                            .font(.system(.body, design: .monospaced))
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(version.isEmpty ? Color.clear : Color.green.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                .disabled(isLoadingVersions)
                            }
                            
                            Divider()
                                .padding(.vertical, 8)
                            
                            // Custom version input
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 6) {
                                    Image(systemName: "pencil.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                    Text(tr("Or enter custom version"))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                TextField(tr("e.g., 3.14.0, latest, latest:lts"), text: $version)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                    .padding(.horizontal, 4)
                            }
                            
                            // Examples
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 6) {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundColor(.yellow)
                                        .font(.caption)
                                    Text(tr("Examples"))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    ExampleRow(icon: "star.fill", text: "latest", description: tr("Latest version"))
                                    ExampleRow(icon: "shield.fill", text: "latest:lts", description: tr("Latest LTS version"))
                                    ExampleRow(icon: "number", text: "18.17.0", description: tr("Specified version"))
                                    ExampleRow(icon: "cup.and.saucer.fill", text: "latest:temurin-17", description: tr("Java specific"))
                                }
                            }
                            .padding()
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                .padding(.vertical, 24)
            }
            .frame(minWidth: 600, idealWidth: 700, minHeight: 500, idealHeight: 600)
            .navigationTitle(tr("Add Language Version"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Cancel")) {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(tr("Add")) {
                        onSave(language, version)
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(language.isEmpty || version.isEmpty)
                }
            }
        }
        .frame(minWidth: 600, idealWidth: 700, minHeight: 500, idealHeight: 600)
        .sheet(isPresented: $showCustomInput) {
            CustomLanguageInputSheet(
                isPresented: $showCustomInput,
                language: $customLanguage,
                onConfirm: { lang in
                    if !lang.isEmpty {
                        language = lang.lowercased()
                        searchText = ""
                        showCustomInput = false
                    }
                }
            )
        }
    }
    
    private func getLanguageIcon(_ language: String) -> String {
        switch language.lowercased() {
        case "javascript": return "🟢"
        case "typescript": return "🟢"
        case "react": return "🟢"
        case "nextjs": return "🟢"
        case "vue": return "🟢"
        case "angular": return "🟢"
        case "svelte": return "🟢"
        case "solid": return "🟢"
        case "tailwind": return "🟢"
        case "bootstrap": return "🟢"
        case "material-ui": return "🟢"
        case "chakra-ui": return "🟢"
        case "emotion": return "🟢"
        case "styled-components": return "🟢"
        case "styled-jsx": return "🟢"
        case "styled-system": return "🟢"
        case "styled-icons": return "🟢"
        case "styled-media-query": return "🟢"
        case "java": return "☕"
        case "kotlin": return "🟢"
        case "scala": return "🟢"
        case "php": return "🐘"
        case "nodejs": return "🟢"
        case "python": return "🐍"
        case "ruby": return "💎"
        case "golang": return "🐹"
        case "rust": return "🦀"
        case "gradle": return "📦"
        case "maven": return "📦"
        case "yarn": return "🧶"
        case "pnpm": return "📦"
        case "npm": return "📦"
        case "elixir": return "💧"
        case "dart": return "🎯"
        case "lua": return "🌙"
        case "r": return "📊"
        case "terraform": return "🏗️"
        case "vault": return "🔐"
        case "consul": return "🌐"
        case "nomad": return "🚀"
        case "erlang": return "⚡"
        case "haskell": return "λ"
        case "ocaml": return "🐫"
        case "swift": return "🐦"
        case "deno": return "🦕"
        case "bun": return "🍞"
        case "crystal": return "💎"
        case "nim": return "🎯"
        case "zig": return "⚡"
        default: return "📝"
        }
    }
    
    private func getVersionOptions() -> [String] {
        if !availableVersions.isEmpty {
            return availableVersions
        }
        return predefinedVersions[language] ?? ["latest", "system"]
    }
    
    private func loadAvailableVersions() {
        guard !language.isEmpty else { return }
        
        isLoadingVersions = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let command = "asdf list all \(language) 2>/dev/null | tail -30"
            let result = Shell.run(command)
            
            // 使用VersionManager的统一过滤方法
            let cleanedVersions = VersionManager.cleanVersionOutput(result.out)
            
            DispatchQueue.main.async {
                if !cleanedVersions.isEmpty {
                    self.availableVersions = ["latest", "system"] + cleanedVersions
                } else {
                    self.availableVersions = predefinedVersions[language] ?? ["latest", "system"]
                }
                self.isLoadingVersions = false
            }
        }
    }
}

// 示例行组件
struct ExampleRow: View {
    let icon: String
    let text: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.caption)
                .frame(width: 20)
            
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
            
            Text("-")
                .foregroundColor(.secondary)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

// 自定义语言输入对话框
struct CustomLanguageInputSheet: View {
    @Binding var isPresented: Bool
    @Binding var language: String
    let onConfirm: (String) -> Void
    
    @State private var inputText: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "keyboard.fill")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                    
                    Text(tr("Enter Custom Language"))
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(tr("Enter the name of the language or tool as it appears in asdf (e.g., nodejs, python, ruby)"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(tr("Language Name"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField(tr("e.g., nodejs, python, ruby"), text: $inputText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .disableAutocorrection(true)
                        .onSubmit {
                            if !inputText.isEmpty {
                                confirm()
                            }
                        }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(tr("Examples:"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• nodejs - Node.js runtime")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("• python - Python interpreter")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("• ruby - Ruby interpreter")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("• terraform - Infrastructure tool")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 8)
                }
                .padding()
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                
                Spacer()
            }
            .padding(24)
            .frame(minWidth: 500, idealWidth: 600, minHeight: 400, idealHeight: 450)
            .navigationTitle(tr("Custom Language"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Cancel")) {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(tr("Confirm")) {
                        confirm()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(inputText.isEmpty)
                }
            }
        }
        .frame(minWidth: 500, idealWidth: 600, minHeight: 400, idealHeight: 450)
        .onAppear {
            inputText = language
        }
    }
    
    private func confirm() {
        if !inputText.isEmpty {
            language = inputText.trimmingCharacters(in: .whitespaces)
            onConfirm(language)
            isPresented = false
        }
    }
}

struct VirtualEnvEditorSheet: View {
    @Binding var isPresented: Bool
    @Binding var language: String
    @Binding var virtualEnv: VirtualEnvironment
    let onSave: (String, VirtualEnvironment) -> Void
    
    private let availableLanguages = ["python", "ruby", "nodejs", "rust"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Language Selection Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text(tr("Language"))
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Picker(tr("Select Language"), selection: $language) {
                            Text(tr("Select a language")).tag("")
                            ForEach(availableLanguages, id: \.self) { lang in
                                Text(lang).tag(lang)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    
                    // Virtual Environment Type Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text(tr("Virtual Environment Type"))
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Picker(tr("Type"), selection: $virtualEnv.type) {
                            ForEach(VirtualEnvType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    
                    // Configuration Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text(tr("Configuration"))
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text(tr("Environment Name"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            TextField(tr("Enter environment name"), text: $virtualEnv.name)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        if virtualEnv.type == .pythonVenv || virtualEnv.type == .pythonConda {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(tr("Python Version (Optional)"))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                TextField(tr("e.g., 3.14.0"), text: Binding(
                                    get: { virtualEnv.pythonVersion ?? "" },
                                    set: { virtualEnv.pythonVersion = $0.isEmpty ? nil : $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                            }
                        }
                        
                        if virtualEnv.type == .rubyGemset {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(tr("Gemset Name (Optional)"))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                TextField(tr("e.g., my-project"), text: Binding(
                                    get: { virtualEnv.gemset ?? "" },
                                    set: { virtualEnv.gemset = $0.isEmpty ? nil : $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                            }
                        }
                        
                        if virtualEnv.type == .nodeNvm {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(tr("Node Version (Optional)"))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                TextField(tr("e.g., 23.11.0"), text: Binding(
                                    get: { virtualEnv.nodeVersion ?? "" },
                                    set: { virtualEnv.nodeVersion = $0.isEmpty ? nil : $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text(tr("Custom Path (Optional)"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            TextField(tr("e.g., ~/.virtualenvs/myenv"), text: Binding(
                                get: { virtualEnv.path ?? "" },
                                set: { virtualEnv.path = $0.isEmpty ? nil : $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                .padding(.vertical, 20)
            }
            .frame(minWidth: 600, idealWidth: 700, minHeight: 500, idealHeight: 600)
            .navigationTitle(tr("Add Virtual Environment"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Cancel")) {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(tr("Add")) {
                        onSave(language, virtualEnv)
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(language.isEmpty || virtualEnv.name.isEmpty)
                }
            }
        }
        .frame(minWidth: 600, idealWidth: 700, minHeight: 500, idealHeight: 600)
    }
}

struct EnvVarEditorSheet: View {
    @Binding var isPresented: Bool
    @Binding var key: String
    @Binding var value: String
    let onSave: (String, String) -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Environment Variable Input Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text(tr("Environment Variable"))
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text(tr("Variable Name"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            TextField(tr("e.g., JAVA_HOME, GRADLE_HOME"), text: $key)
                                .textFieldStyle(.roundedBorder)
                                .disableAutocorrection(true)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text(tr("Value"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if #available(macOS 13.0, *) {
                                TextField(tr("Enter environment variable value"), text: $value, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(3...6)
                            } else {
                                TextField(tr("Enter environment variable value"), text: $value)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Examples Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text(tr("Examples"))
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("JAVA_HOME")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("/Library/Java/JavaVirtualMachines/jdk1.8.0_361.jdk/Contents/Home")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("GRADLE_HOME")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("/opt/shared_env/android/gradle-7.6.1")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("NODE_ENV")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("development")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                .padding(.vertical, 20)
            }
            .frame(minWidth: 600, idealWidth: 700, minHeight: 500, idealHeight: 600)
            .navigationTitle(tr("Add Environment Variable"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Cancel")) {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(tr("Add")) {
                        onSave(key, value)
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(key.isEmpty || value.isEmpty)
                }
            }
        }
        .frame(minWidth: 600, idealWidth: 700, minHeight: 500, idealHeight: 600)
    }
}

#Preview {
    EnvironmentEditorView(
        isPresented: .constant(true),
        profile: .constant(EnvironmentProfile(name: "Test", description: "", versions: [:])),
        isNew: true,
        onSave: { _ in }
    )
}

// 环境变量行组件 - 支持直接编辑
struct EnvironmentVariableRow: View {
    let key: String
    @Binding var value: String
    let onKeyChange: (String, String) -> Void
    let onDelete: () -> Void
    
    @State private var editingKey: String
    @State private var previousKey: String
    
    init(key: String, value: Binding<String>, onKeyChange: @escaping (String, String) -> Void, onDelete: @escaping () -> Void) {
        self.key = key
        self._value = value
        self.onKeyChange = onKeyChange
        self.onDelete = onDelete
        self._editingKey = State(initialValue: key)
        self._previousKey = State(initialValue: key)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 变量名 - 可编辑
            VStack(alignment: .leading, spacing: 4) {
                Text(tr("Variable Name"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField(tr("e.g., JAVA_HOME"), text: $editingKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .disableAutocorrection(true)
                    .onChange(of: editingKey) { newValue in
                        if previousKey != newValue && !newValue.isEmpty {
                            onKeyChange(previousKey, newValue)
                            previousKey = newValue
                        }
                    }
                    .onAppear {
                        editingKey = key
                        previousKey = key
                    }
            }
            .frame(maxWidth: .infinity)
            
            // 变量值 - 可编辑
            VStack(alignment: .leading, spacing: 4) {
                Text(tr("Value"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField(tr("Enter value"), text: $value)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }
            .frame(maxWidth: .infinity)
            
            // 删除按钮
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help(tr("Remove"))
            .padding(.top, 20)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
    }
}