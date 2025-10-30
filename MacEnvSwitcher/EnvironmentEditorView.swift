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
            Form {
                // Basic info section
                Section(tr("Basic Information")) {
                    TextField(tr("Environment Name"), text: $editedProfile.name)
                    if #available(macOS 13.0, *) {
                        TextField(tr("Description (Optional)"), text: $editedProfile.description, axis: .vertical)
                            .lineLimit(3)
                    } else {
                        TextField(tr("Description (Optional)"), text: $editedProfile.description)
                    }
                }
                
                // Language versions section
                Section(tr("Language Versions")) {
                    ForEach(editedProfile.versions.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack {
                            Text(key).bold()
                            Spacer()
                            Text(value).foregroundColor(.secondary)
                            Button(action: {
                                editedProfile.versions.removeValue(forKey: key)
                            }) {
                                Image(systemName: "minus.circle.fill").foregroundColor(.red)
                            }
                        }
                    }
                    
                    Button(tr("Add Language Version")) {
                        selectedLanguage = ""
                        selectedVersion = ""
                        showVersionEditor = true
                    }
                }
                
                // Virtual environments section
                Section(tr("Virtual Environments")) {
                    ForEach(editedProfile.virtualEnvs.sorted(by: { $0.key < $1.key }), id: \.key) { key, venv in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(key).bold()
                                Spacer()
                                Button(action: {
                                    editedProfile.virtualEnvs.removeValue(forKey: key)
                                }) {
                                    Image(systemName: "minus.circle.fill").foregroundColor(.red)
                                }
                            }
                            Text("\(venv.type.displayName): \(venv.name)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(tr("Add Virtual Environment")) {
                        selectedLanguage = ""
                        selectedVirtualEnv = VirtualEnvironment(type: .pythonVenv, name: "")
                        showVirtualEnvEditor = true
                    }
                }
                
                // Environment variables section
                Section(tr("Environment Variables")) {
                    ForEach(editedProfile.environmentVars.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack {
                            Text(key).bold()
                            Spacer()
                            Text(value).foregroundColor(.secondary)
                            Button(action: {
                                editedProfile.environmentVars.removeValue(forKey: key)
                            }) {
                                Image(systemName: "minus.circle.fill").foregroundColor(.red)
                            }
                        }
                    }
                    
                    Button(tr("Add Environment Variable")) {
                        selectedEnvKey = ""
                        selectedEnvValue = ""
                        showEnvVarEditor = true
                    }
                }
            }
            .frame(minWidth: 700)
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
                    .disabled(editedProfile.name.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showVersionEditor) {
            VersionEditorSheet(
                isPresented: $showVersionEditor,
                language: $selectedLanguage,
                version: $selectedVersion,
                onSave: { lang, ver in
                    editedProfile.versions[lang] = ver
                }
            )
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
            Form {
                Section(tr("Language")) {
                    Picker(tr("Select Language"), selection: $language) {
                        ForEach(availableLanguages, id: \.self) { lang in
                            Text(lang).tag(lang)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(tr("Version")) {
                    HStack {
                        // 版本下拉选择
                        Menu {
                            ForEach(getVersionOptions(), id: \.self) { ver in
                                Button(ver) {
                                    version = ver
                                }
                            }
                            
                            if !language.isEmpty {
                                Divider()
                                
                                Button(action: {
                                    loadAvailableVersions()
                                }) {
                                    HStack {
                                        Text(tr("Refresh Versions"))
                                        if isLoadingVersions {
                                            ProgressView()
                                                .scaleEffect(0.6)
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(version.isEmpty ? tr("Select Version") : version)
                                    .foregroundColor(version.isEmpty ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "chevron.down.circle")
                            }
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(6)
                        }
                        .disabled(language.isEmpty || isLoadingVersions)
                    }
                    
                    // 自定义输入框
                    TextField(tr("Or enter custom version"), text: $version)
                        .textFieldStyle(.roundedBorder)
                        .disabled(language.isEmpty)
                    
                    Text(tr("Examples:"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("• latest - Latest version")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("• latest:lts - Latest LTS version")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("• 18.17.0 - Specific version")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("• latest:temurin-17 - Java specific")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
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
                    .disabled(language.isEmpty || version.isEmpty)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 450)
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
            let command = "asdf list-all \(language) 2>/dev/null | tail -30"
            let result = Shell.run(command)
            let versions = result.out.split(separator: "\n")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            DispatchQueue.main.async {
                if !versions.isEmpty {
                    self.availableVersions = ["latest", "system"] + versions
                } else {
                    self.availableVersions = predefinedVersions[language] ?? ["latest", "system"]
                }
                self.isLoadingVersions = false
            }
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
            Form {
                Section(tr("Language")) {
                    Picker(tr("Select Language"), selection: $language) {
                        ForEach(availableLanguages, id: \.self) { lang in
                            Text(lang).tag(lang)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(tr("Virtual Environment Type")) {
                    Picker(tr("Type"), selection: $virtualEnv.type) {
                        ForEach(VirtualEnvType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(tr("Configuration")) {
                    TextField(tr("Environment Name"), text: $virtualEnv.name)
                    
                    if virtualEnv.type == .pythonVenv || virtualEnv.type == .pythonConda {
                        TextField(tr("Python Version (Optional)"), text: Binding(
                            get: { virtualEnv.pythonVersion ?? "" },
                            set: { virtualEnv.pythonVersion = $0.isEmpty ? nil : $0 }
                        ))
                    }
                    
                    if virtualEnv.type == .rubyGemset {
                        TextField(tr("Gemset Name (Optional)"), text: Binding(
                            get: { virtualEnv.gemset ?? "" },
                            set: { virtualEnv.gemset = $0.isEmpty ? nil : $0 }
                        ))
                    }
                    
                    if virtualEnv.type == .nodeNvm {
                        TextField(tr("Node Version (Optional)"), text: Binding(
                            get: { virtualEnv.nodeVersion ?? "" },
                            set: { virtualEnv.nodeVersion = $0.isEmpty ? nil : $0 }
                        ))
                    }
                    
                    TextField(tr("Custom Path (Optional)"), text: Binding(
                        get: { virtualEnv.path ?? "" },
                        set: { virtualEnv.path = $0.isEmpty ? nil : $0 }
                    ))
                }
            }
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
                    .disabled(language.isEmpty || virtualEnv.name.isEmpty)
                }
            }
        }
    }
}

struct EnvVarEditorSheet: View {
    @Binding var isPresented: Bool
    @Binding var key: String
    @Binding var value: String
    let onSave: (String, String) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(tr("Environment Variable")) {
                    TextField(tr("Variable Name (e.g., JAVA_HOME)"), text: $key)
                    if #available(macOS 13.0, *) {
                        TextField(tr("Value"), text: $value, axis: .vertical)
                            .lineLimit(3)
                    } else {
                        TextField(tr("Value"), text: $value)
                    }
                }
                
                Section(tr("Examples")) {
                    Text("JAVA_HOME=/usr/local/java")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("PATH=$PATH:/custom/bin")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("NODE_ENV=development")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
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
                    .disabled(key.isEmpty || value.isEmpty)
                }
            }
        }
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