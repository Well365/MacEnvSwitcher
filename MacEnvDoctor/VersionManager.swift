import SwiftUI
import Foundation

// 版本管理器 - 处理开发环境版本选择
class VersionManager: ObservableObject {
    static let shared = VersionManager()
    
    // 预定义的版本选项
    private let predefinedVersions: [TaskID: [String]] = [
        .python3: ["3.12.0", "3.11.6", "3.10.13", "3.9.18", "3.8.18", "system", "latest"],
        .ruby: ["3.2.0", "3.1.4", "3.0.6", "2.7.8", "2.6.10", "system", "latest"],
        .nodejs: ["20.9.0", "18.18.2", "16.20.2", "14.21.3", "system", "latest"],
        .golang: ["1.21.4", "1.20.11", "1.19.13", "system", "latest"],
        .java: ["openjdk-21", "openjdk-17", "openjdk-11", "openjdk-8", "system", "latest"],
        .rust: ["1.74.0", "1.73.0", "1.72.1", "stable", "beta", "nightly", "system", "latest"]
    ]
    
    // 动态版本缓存
    @Published var availableVersions: [TaskID: [String]] = [:]
    @Published var isLoadingVersions: Set<TaskID> = []
    
    private init() {
        // 初始化预定义版本
        availableVersions = predefinedVersions
    }
    
    // 获取指定任务的可用版本
    func getVersions(for task: TaskID) -> [String] {
        return availableVersions[task] ?? ["system", "latest"]
    }
    
    // 异步加载实际可用版本
    func loadAvailableVersions(for task: TaskID) {
        guard !isLoadingVersions.contains(task) else { return }
        
        isLoadingVersions.insert(task)
        
        Task {
            let versions = await fetchVersionsFromSystem(for: task)
            
            await MainActor.run {
                if !versions.isEmpty {
                    // 合并预定义版本和系统版本，去重
                    var allVersions = predefinedVersions[task] ?? []
                    allVersions.append(contentsOf: versions)
                    availableVersions[task] = Array(Set(allVersions)).sorted { version1, version2 in
                        // 特殊版本排序
                        if version1 == "latest" { return true }
                        if version2 == "latest" { return false }
                        if version1 == "system" { return true }
                        if version2 == "system" { return false }
                        
                        // 版本号排序（降序）
                        return version1.compare(version2, options: .numeric) == .orderedDescending
                    }
                }
                isLoadingVersions.remove(task)
            }
        }
    }
    
    // 从系统获取可用版本
    private func fetchVersionsFromSystem(for task: TaskID) async -> [String] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let versions = self.executeVersionCommand(for: task)
                continuation.resume(returning: versions)
            }
        }
    }
    
    // 执行版本查询命令
    private func executeVersionCommand(for task: TaskID) -> [String] {
        let command: String
        
        switch task {
        case .python3:
            command = "asdf list-all python 2>/dev/null | tail -20"
        case .ruby:
            command = "asdf list-all ruby 2>/dev/null | tail -20"
        case .nodejs:
            command = "asdf list-all nodejs 2>/dev/null | tail -20"
        case .golang:
            command = "asdf list-all golang 2>/dev/null | tail -20"
        case .java:
            command = "asdf list-all java 2>/dev/null | grep openjdk | tail -10"
        case .rust:
            command = "asdf list-all rust 2>/dev/null | tail -10"
        default:
            return []
        }
        
        let result = Shell.run(command)
        let output = result.out
        return output.split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    // 验证版本是否有效
    func isValidVersion(_ version: String, for task: TaskID) -> Bool {
        let versions = getVersions(for: task)
        return versions.contains(version) || version == "system" || version == "latest"
    }
    
    // 获取推荐版本
    func getRecommendedVersion(for task: TaskID) -> String {
        let versions = getVersions(for: task)
        
        // 优先返回最新的稳定版本
        for version in versions {
            if version != "latest" && version != "system" && version != "nightly" && version != "beta" {
                return version
            }
        }
        
        return "latest"
    }
}

// 版本选择器视图
struct VersionPickerView: View {
    let task: TaskID
    @Binding var selectedVersion: String
    @ObservedObject private var versionManager = VersionManager.shared
    @State private var customVersion: String = ""
    @State private var showCustomInput: Bool = false
    
    var body: some View {
        HStack(spacing: 6) {
            // 主版本选择器 - 只显示版本号
            Picker("", selection: $selectedVersion) {
                ForEach(versionManager.getVersions(for: task), id: \.self) { version in
                    Text(version)
                        .tag(version)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)
            .onChange(of: selectedVersion) { newValue in
                if newValue == "custom" {
                    showCustomInput = true
                }
            }
            
            // 列出版本按钮
            Button(action: {
                versionManager.loadAvailableVersions(for: task)
            }) {
                if versionManager.isLoadingVersions.contains(task) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 80, height: 20)
                } else {
                    Text(tr("List Versions"))
                        .font(.caption)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(versionManager.isLoadingVersions.contains(task))
        }
        .onAppear {
            // 首次加载时设置默认版本
            if selectedVersion.isEmpty {
                selectedVersion = versionManager.getRecommendedVersion(for: task)
            }
        }
        .sheet(isPresented: $showCustomInput) {
            CustomVersionInputView(
                task: task,
                customVersion: $customVersion,
                selectedVersion: $selectedVersion,
                isPresented: $showCustomInput
            )
        }
    }
}

// 自定义版本输入视图
struct CustomVersionInputView: View {
    let task: TaskID
    @Binding var customVersion: String
    @Binding var selectedVersion: String
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text(tr("Enter Custom Version for ") + task.displayName)
                    .font(.headline)
                
                TextField(tr("Version (e.g., 3.11.5)"), text: $customVersion)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)
                
                Text(tr("Examples: 3.11.5, 2.7.18, latest, system"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle(tr("Custom Version"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Cancel")) {
                        selectedVersion = VersionManager.shared.getRecommendedVersion(for: task)
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(tr("Confirm")) {
                        if !customVersion.isEmpty {
                            selectedVersion = customVersion
                        } else {
                            selectedVersion = VersionManager.shared.getRecommendedVersion(for: task)
                        }
                        isPresented = false
                    }
                    .disabled(customVersion.isEmpty)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 200)
    }
}