import Foundation
import SwiftUI

// MARK: - Switch Log Entry
struct SwitchLogEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let profileName: String
    let tool: String
    let fromVersion: String?
    let toVersion: String
    let fromSource: String?
    let toSource: String
    let success: Bool
    let log: String
    let errorMessage: String?
    
    init(
        profileName: String,
        tool: String,
        fromVersion: String? = nil,
        toVersion: String,
        fromSource: String? = nil,
        toSource: String,
        success: Bool,
        log: String,
        errorMessage: String? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.profileName = profileName
        self.tool = tool
        self.fromVersion = fromVersion
        self.toVersion = toVersion
        self.fromSource = fromSource
        self.toSource = toSource
        self.success = success
        self.log = log
        self.errorMessage = errorMessage
    }
}

// MARK: - Switch Log Manager
class SwitchLogManager: ObservableObject {
    static let shared = SwitchLogManager()
    
    @Published var logs: [SwitchLogEntry] = []
    
    private let logDirectory: URL
    private let logFile: URL
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        logDirectory = appSupport.appendingPathComponent("MacEnvSwitcher/Logs")
        logFile = logDirectory.appendingPathComponent("switch_logs.json")
        
        // 确保目录存在
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        
        // 加载历史日志
        loadLogs()
    }
    
    /// 记录切换日志
    func logSwitch(
        profileName: String,
        tool: String,
        fromVersion: String? = nil,
        toVersion: String,
        fromSource: String? = nil,
        toSource: String,
        success: Bool,
        log: String,
        errorMessage: String? = nil
    ) {
        let entry = SwitchLogEntry(
            profileName: profileName,
            tool: tool,
            fromVersion: fromVersion,
            toVersion: toVersion,
            fromSource: fromSource,
            toSource: toSource,
            success: success,
            log: log,
            errorMessage: errorMessage
        )
        
        DispatchQueue.main.async {
            self.logs.insert(entry, at: 0) // 最新的在前面
            self.saveLogs()
        }
    }
    
    /// 记录环境切换日志
    func logEnvironmentSwitch(
        profileName: String,
        success: Bool,
        log: String,
        details: [String: (from: String?, to: String, fromSource: String?, toSource: String, success: Bool)] = [:]
    ) {
        // 记录整体切换日志
        logSwitch(
            profileName: profileName,
            tool: "environment",
            fromVersion: nil,
            toVersion: profileName,
            fromSource: nil,
            toSource: "profile",
            success: success,
            log: log,
            errorMessage: success ? nil : "环境切换失败"
        )
        
        // 记录每个工具的切换详情
        for (tool, detail) in details {
            logSwitch(
                profileName: profileName,
                tool: tool,
                fromVersion: detail.from,
                toVersion: detail.to,
                fromSource: detail.fromSource,
                toSource: detail.toSource,
                success: detail.success,
                log: "",
                errorMessage: detail.success ? nil : "\(tool) 切换失败"
            )
        }
    }
    
    /// 保存日志到文件
    private func saveLogs() {
        // 只保留最近 1000 条日志
        let logsToSave = Array(logs.prefix(1000))
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(logsToSave)
            try data.write(to: logFile)
        } catch {
            print("⚠️ Failed to save switch logs: \(error)")
        }
    }
    
    /// 从文件加载日志
    private func loadLogs() {
        guard FileManager.default.fileExists(atPath: logFile.path),
              let data = try? Data(contentsOf: logFile) else {
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            logs = try decoder.decode([SwitchLogEntry].self, from: data)
        } catch {
            print("⚠️ Failed to load switch logs: \(error)")
            logs = []
        }
    }
    
    /// 清空日志
    func clearLogs() {
        logs = []
        try? FileManager.default.removeItem(at: logFile)
        saveLogs()
    }
    
    /// 删除指定日志
    func deleteLog(_ log: SwitchLogEntry) {
        logs.removeAll { $0.id == log.id }
        saveLogs()
    }
    
    /// 按条件筛选日志
    func filterLogs(
        profileName: String? = nil,
        tool: String? = nil,
        success: Bool? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) -> [SwitchLogEntry] {
        return logs.filter { log in
            if let profileName = profileName, log.profileName != profileName {
                return false
            }
            if let tool = tool, log.tool != tool {
                return false
            }
            if let success = success, log.success != success {
                return false
            }
            if let startDate = startDate, log.timestamp < startDate {
                return false
            }
            if let endDate = endDate, log.timestamp > endDate {
                return false
            }
            return true
        }
    }
}

