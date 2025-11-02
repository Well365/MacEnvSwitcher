import SwiftUI

// MARK: - Switch Log View
struct SwitchLogView: View {
    @StateObject private var logManager = SwitchLogManager.shared
    @State private var selectedProfile: String? = nil
    @State private var selectedTool: String? = nil
    @State private var filterSuccess: Bool? = nil
    @State private var searchText: String = ""
    @State private var showDetail: SwitchLogEntry? = nil
    
    private var filteredLogs: [SwitchLogEntry] {
        var logs = logManager.logs
        
        if let profile = selectedProfile {
            logs = logs.filter { $0.profileName == profile }
        }
        
        if let tool = selectedTool {
            logs = logs.filter { $0.tool == tool }
        }
        
        if let success = filterSuccess {
            logs = logs.filter { $0.success == success }
        }
        
        if !searchText.isEmpty {
            logs = logs.filter {
                $0.profileName.localizedCaseInsensitiveContains(searchText) ||
                $0.tool.localizedCaseInsensitiveContains(searchText) ||
                ($0.toVersion.localizedCaseInsensitiveContains(searchText)) ||
                ($0.log.localizedCaseInsensitiveContains(searchText))
            }
        }
        
        return logs
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索和筛选栏
                VStack(spacing: 12) {
                    // 搜索框
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField(tr("Search logs..."), text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    
                    // 筛选器
                    HStack(spacing: 12) {
                        // Profile 筛选
                        Menu {
                            Button(tr("All Profiles")) {
                                selectedProfile = nil
                            }
                            Divider()
                            ForEach(uniqueProfiles, id: \.self) { profile in
                                Button(profile) {
                                    selectedProfile = profile
                                }
                            }
                        } label: {
                            Label(selectedProfile ?? tr("All Profiles"), systemImage: "list.bullet")
                                .frame(maxWidth: .infinity)
                        }
                        .menuStyle(.borderedButton)
                        
                        // Tool 筛选
                        Menu {
                            Button(tr("All Tools")) {
                                selectedTool = nil
                            }
                            Divider()
                            ForEach(uniqueTools, id: \.self) { tool in
                                Button(tool) {
                                    selectedTool = tool
                                }
                            }
                        } label: {
                            Label(selectedTool ?? tr("All Tools"), systemImage: "wrench")
                                .frame(maxWidth: .infinity)
                        }
                        .menuStyle(.borderedButton)
                        
                        // 成功/失败筛选
                        Menu {
                            Button(tr("All")) {
                                filterSuccess = nil
                            }
                            Divider()
                            Button(tr("Success")) {
                                filterSuccess = true
                            }
                            Button(tr("Failed")) {
                                filterSuccess = false
                            }
                        } label: {
                            Label(
                                filterSuccess == nil ? tr("All") : (filterSuccess == true ? tr("Success") : tr("Failed")),
                                systemImage: filterSuccess == nil ? "circle" : (filterSuccess == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                            )
                            .foregroundColor(filterSuccess == nil ? .primary : (filterSuccess == true ? .green : .red))
                            .frame(maxWidth: .infinity)
                        }
                        .menuStyle(.borderedButton)
                        
                        // 清空按钮
                        Button(action: {
                            logManager.clearLogs()
                        }) {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.bordered)
                        .help(tr("Clear All Logs"))
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // 日志列表
                if filteredLogs.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(tr("No logs found"))
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredLogs) { log in
                        LogEntryRow(log: log)
                            .onTapGesture {
                                showDetail = log
                            }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                }
            }
            .navigationTitle(tr("Switch Logs"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        logManager.clearLogs()
                    }) {
                        Label(tr("Clear"), systemImage: "trash")
                    }
                }
            }
            .sheet(item: $showDetail) { log in
                LogDetailView(log: log)
            }
        }
        .frame(minWidth: 800, idealWidth: 1000, minHeight: 600, idealHeight: 700)
    }
    
    private var uniqueProfiles: [String] {
        Array(Set(logManager.logs.map { $0.profileName })).sorted()
    }
    
    private var uniqueTools: [String] {
        Array(Set(logManager.logs.map { $0.tool })).sorted()
    }
}

// MARK: - Log Entry Row
struct LogEntryRow: View {
    let log: SwitchLogEntry
    
    var body: some View {
        HStack(spacing: 12) {
            // 状态图标
            Image(systemName: log.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(log.success ? .green : .red)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                // 工具和版本信息
                HStack {
                    Text(log.tool)
                        .font(.headline)
                    Text("→")
                        .foregroundColor(.secondary)
                    Text(log.toVersion)
                        .font(.headline)
                    if let fromVersion = log.fromVersion {
                        Text("(from \(fromVersion))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 来源信息
                HStack {
                    if let fromSource = log.fromSource {
                        Label(fromSource, systemImage: "arrow.left")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Label(log.toSource, systemImage: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // 时间和 Profile
                HStack {
                    Text(log.profileName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(log.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 日志预览
            if !log.log.isEmpty {
                Text(log.log.prefix(50))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Log Detail View
struct LogDetailView: View {
    let log: SwitchLogEntry
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 基本信息
                    VStack(alignment: .leading, spacing: 12) {
                        Text(tr("Basic Information"))
                            .font(.headline)
                        
                        LogInfoRow(label: tr("Profile"), value: log.profileName)
                        LogInfoRow(label: tr("Tool"), value: log.tool)
                        LogInfoRow(label: tr("Status"), value: log.success ? tr("Success") : tr("Failed"))
                        
                        if let fromVersion = log.fromVersion {
                            LogInfoRow(label: tr("From Version"), value: fromVersion)
                        }
                        LogInfoRow(label: tr("To Version"), value: log.toVersion)
                        
                        if let fromSource = log.fromSource {
                            LogInfoRow(label: tr("From Source"), value: fromSource)
                        }
                        LogInfoRow(label: tr("To Source"), value: log.toSource)
                        
                        LogInfoRow(label: tr("Timestamp"), value: log.timestamp.formatted(date: .complete, time: .complete))
                    }
                    .padding()
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    
                    // 错误信息
                    if let errorMessage = log.errorMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(tr("Error Message"))
                                .font(.headline)
                            Text(errorMessage)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.red)
                        }
                        .padding()
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                    }
                    
                    // 详细日志
                    if !log.log.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(tr("Detailed Log"))
                                .font(.headline)
                            
                            ScrollView {
                                Text(log.log)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                            }
                            .frame(maxHeight: 300)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
            .frame(minWidth: 600, idealWidth: 700, minHeight: 500, idealHeight: 600)
            .navigationTitle(tr("Log Details"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Close")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Log Info Row
struct LogInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

