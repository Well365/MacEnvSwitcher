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
                                ForEach(editedProfile.environmentVars.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                    HStack {
                                        Text(key)
                                            .font(.body)
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text(value)
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                        Button(action: {
                                            editedProfile.environmentVars.removeValue(forKey: key)
                                        }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Color(NSColor.textBackgroundColor))
                                    .cornerRadius(8)
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
    
    private let availableLanguages = ["nodejs", "python", "ruby", "java", "golang", "rust", "gradle", "maven", "yarn", "pnpm"]
    
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
                            
                            Menu {
                                ForEach(availableLanguages, id: \.self) { lang in
                                    Button(action: {
                                        language = lang
                                    }) {
                                        HStack {
                                            Text(getLanguageIcon(lang))
                                            Text(lang.capitalized)
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    if language.isEmpty {
                                        Text(tr("-- Select a language --"))
                                            .foregroundColor(.secondary)
                                    } else {
                                        HStack(spacing: 6) {
                                            Text(getLanguageIcon(language))
                                            Text(language.capitalized)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(10)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(language.isEmpty ? Color.clear : Color.blue.opacity(0.3), lineWidth: 1)
                            )
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
    }
    
    private func getLanguageIcon(_ language: String) -> String {
        switch language.lowercased() {
        case "javascript": return "🟢 JavaScript"
        case "typescript": return "🟢 TypeScript"
        case "react": return "🟢 React"
        case "nextjs": return "🟢 Next.js"
        case "vue": return "🟢 Vue"
        case "angular": return "🟢 Angular"
        case "svelte": return "🟢 Svelte"
        case "solid": return "🟢 Solid"
        case "tailwind": return "🟢 Tailwind"
        case "bootstrap": return "🟢 Bootstrap"
        case "material-ui": return "🟢 Material-UI"
        case "chakra-ui": return "🟢 Chakra-UI"
        case "emotion": return "🟢 Emotion"
        case "styled-components": return "🟢 Styled Components"
        case "styled-jsx": return "🟢 Styled JSX"
        case "styled-system": return "🟢 Styled System"
        case "styled-icons": return "🟢 Styled Icons"
        case "styled-media-query": return "🟢 Styled Media Query"
        case "styled-media-query": return "🟢 Styled Media Query"
        case "java": return "☕ Java"
        case "kotlin": return "🟢 Kotlin"
        case "scala": return "🟢 Scala"
        case "php": return "🟢 PHP"
        case "nodejs": return "🟢 Node.js"
        case "python": return "🐍 Python"
        case "ruby": return "💎 Ruby"
        case "java": return "☕ Java"
        case "golang": return "🐹 Golang"
        case "rust": return "🦀 Rust"
        case "gradle": return "📦 Gradle"
        case "maven": return "📦 Maven"
        case "yarn": return "🧶 Yarn"
        case "pnpm": return "📦 Pnpm"
        default: return "📝 Other"
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