
import SwiftUI

struct ContentView: View {
    @StateObject private var vm = BootstrapViewModel()
    @State private var autoYes = false
    @State private var showReport = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            controlBar
            profilesBar
            groupsBar
            taskList
            Divider()
            footer
        }
        .padding(16)
        .sheet(isPresented: $vm.showEditor) {
            ProfileEditorView(isPresented: $vm.showEditor)
        }
        .alert(tr("Report saved"), isPresented: $showReport) {
            Button(tr("OK"), role: .cancel) {}
        } message: { Text(vm.lastReportPath ?? "") }
        .onAppear { vm.runFullCheck() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(tr("MacEnvDoctor – One-click Check & Optional Install")).font(.title2).bold()
            Text(tr("Check/Install: Xcode, CLT, iTerm2, oh-my-bash, Homebrew, Python3, Ruby, fastlane, asdf, Node.js, Go, Java, pnpm, yarn, Maven, Gradle, Python(asdf), Rust(asdf), jabba"))
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            Button(tr("Re-Check")) { vm.runFullCheck() }
            Button(tr("Install Missing")) { vm.installMissing(autoYes: autoYes) }
            Toggle(tr("Auto Confirm"), isOn: $autoYes).toggleStyle(.switch)
            Spacer()
            Button(tr("Open Xcode in App Store")) { vm.openXcodeAppStore() }
        }
    }

    private var profilesBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(tr("Environment Profiles (Version Matrix)")).font(.headline)
                Spacer()
                Button(tr("Open Editor")) { vm.showEditor = true }
            }
            HStack(spacing: 12) {
                Picker(tr("Select Profile"), selection: $vm.selectedProfile) {
                    Text(tr("None")).tag(EnvironmentProfile?.none)
                    ForEach(vm.profiles, id: \.self) { p in
                        Text(p.name).tag(EnvironmentProfile?.some(p))
                    }
                }.frame(maxWidth: 360)
                Button(tr("Apply Profile")) { vm.applySelectedProfile() }
                Button(tr("Export Sample")) { vm.exportProfilesSample() }
                Button(tr("Reload")) { vm.reloadProfiles() }
                Text(tr("Profiles file: ")) + Text("~/.mac-bootstrap/profiles.json").font(.caption).foregroundStyle(.secondary)
            }
            if let p = vm.selectedProfile {
                ScrollView {
                    VStack(alignment: .leading) {
                        ForEach(p.versions.sorted(by: { $0.key < $1.key }), id: \.key) { k, v in
                            HStack { Text(k).bold(); Spacer(); Text(v) }
                            Divider()
                        }
                    }
                }.frame(maxHeight: 140).background(.black.opacity(0.04)).clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var groupsBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tr("Profile Groups")).font(.headline)
            HStack(spacing: 12) {
                Picker(tr("Select Group"), selection: $vm.selectedGroup) {
                    Text(tr("None")).tag(ProfileGroup?.none)
                    ForEach(vm.groups, id: \.self) { g in
                        Text(g.name).tag(ProfileGroup?.some(g))
                    }
                }.frame(maxWidth: 360)
                Button(tr("Apply Group")) { vm.applySelectedGroup() }
                Button(tr("Export Sample")) { vm.exportGroupsSample() }
                Button(tr("Reload")) { vm.reloadGroups() }
                Text(tr("Groups file: ")) + Text("~/.mac-bootstrap/groups.json").font(.caption).foregroundStyle(.secondary)
            }
            if let g = vm.selectedGroup {
                ScrollView {
                    VStack(alignment: .leading) {
                        ForEach(g.profileNames, id: \.self) { name in
                            HStack { Text("• " + name); Spacer() }
                            Divider()
                        }
                    }
                }.frame(maxHeight: 100).background(.black.opacity(0.04)).clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var taskList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(TaskID.allCases, id: \.self) { t in
                    TaskRow(task: t,
                            state: vm.state[t] ?? .init(),
                            onCheck: { vm.check(t) },
                            onInstall: { vm.install(t, autoYes: autoYes) },
                            onToggleSkip: { vm.toggleSkip(t) },
                            onInstallLatest: { vm.installLatest(t) },
                            onList: { vm.listVersions(t) },
                            onInstallVer: { ver in vm.installVersion(t, version: ver) },
                            onSetDefault: { ver in vm.setDefault(t, version: ver) }
                    )
                    .padding(12)
                    .background(.background.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button(tr("Generate Report (JSON)")) {
                vm.saveReportJSON()
                showReport = true
            }.keyboardShortcut("r", modifiers: [.command])

            if let path = vm.lastReportPath {
                Text(tr("Saved to: ") + path).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(vm.summaryLine).font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct TaskRow: View {
    let task: TaskID
    let state: TaskState
    var onCheck: () -> Void
    var onInstall: () -> Void
    var onToggleSkip: () -> Void
    var onInstallLatest: () -> Void
    var onList: () -> Void
    var onInstallVer: (String) -> Void
    var onSetDefault: (String) -> Void
    @State private var versionInput: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: state.isBusy ? "hourglass" : (state.installed == true ? "checkmark.seal.fill" : (state.installed == false ? "exclamationmark.triangle.fill" : "questionmark.circle")))
                    .foregroundStyle(state.isBusy ? .yellow : (state.installed == true ? .green : (state.installed == false ? .orange : .gray)))
                Text(task.displayName).font(.headline)
                Spacer()
                Button(tr("Check")) { onCheck() }
                Button(tr("Install / Fix")) { onInstall() }
                Toggle(tr("Skip"), isOn: .init(get: { state.isSkipped }, set: { _ in onToggleSkip() })).labelsHidden()
            }
            if state.supportsVersioning {
                HStack(spacing: 8) {
                    Text(tr("Version:"))
                    TextField(tr("e.g. 20.14.0 / latest / latest:lts / 1.21 / temurin-17"), text: $versionInput)
                        .textFieldStyle(.roundedBorder).frame(maxWidth: 520)
                    Button(tr("Install Ver")) { onInstallVer(versionInput) }
                    Button(tr("Set Default")) { onSetDefault(versionInput) }
                    Button(tr("Latest")) { onInstallLatest() }
                    Button(tr("List")) { onList() }
                }.font(.caption)
            }
            if let tip = state.tip, !tip.isEmpty {
                Text(tip).font(.caption).foregroundStyle(.secondary)
            }
            if !state.log.isEmpty {
                ScrollView {
                    Text(state.log)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 180)
                .background(.black.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}
