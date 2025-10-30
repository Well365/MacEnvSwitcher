
import SwiftUI
import UniformTypeIdentifiers

struct ProfileEditorView: View {
    @Binding var isPresented: Bool

    @State private var profiles: [EnvironmentProfile] = ProfilesStore.loadProfiles()
    @State private var groups: [ProfileGroup] = ProfilesStore.loadGroups()
    @State private var selectedProfile: EnvironmentProfile? = nil
    @State private var selectedGroup: ProfileGroup? = nil
    @State private var syncFolder: URL? = ProfilesStore.getSyncFolder()
    @State private var log: String = ""

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(tr("Profile Visual Editor")).font(.title3).bold()
                Spacer()
                Button(tr("Close")) { isPresented = false }
            }
            TabView {
                profilesTab
                    .tabItem { Label(tr("Profiles"), systemImage: "square.grid.2x2") }
                groupsTab
                    .tabItem { Label(tr("Groups"), systemImage: "person.3") }
                syncTab
                    .tabItem { Label(tr("Team Sync"), systemImage: "arrow.triangle.2.circlepath") }
            }.frame(height: 520)

            if !log.isEmpty {
                ScrollView {
                    Text(log).font(.system(.caption, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading)
                }.frame(maxHeight: 120).background(.black.opacity(0.04)).clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .frame(minWidth: 960)
    }

    // MARK: - Profiles Tab
    private var profilesTab: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading) {
                HStack {
                    Text(tr("Profiles")).font(.headline)
                    Spacer()
                    Button(tr("Add")) { addProfile() }
                    Button(tr("Duplicate")) { duplicateProfile() }
                    Button(tr("Delete")) { deleteProfile() }
                }
                HStack {
                    Button(tr("Detect System")) { detectCurrentSystem() }
                        .help(tr("Auto-detect current system configuration and create a profile"))
                    Spacer()
                }
                List(selection: Binding(get: {
                    selectedProfile == nil ? Set<EnvironmentProfile.ID>() : [selectedProfile!.id]
                }, set: { ids in
                    if let id = ids.first { selectedProfile = profiles.first(where: {$0.id == id}) }
                })) {
                    ForEach(profiles) { p in
                        Text(p.name).tag(p.id)
                    }
                }.frame(width: 260, height: 420)
                HStack {
                    Button(tr("Import...")) { ProfilesStore.importProfilesViaPanel { imported in
                        if imported.isEmpty { return }
                        profiles = ProfilesStore.mergeProfiles(base: profiles, incoming: imported); ProfilesStore.saveProfiles(profiles)
                        log.append("\nImported profiles: \(imported.count)")
                    }}
                    Button(tr("Export...")) { ProfilesStore.exportProfilesViaPanel(profiles) }
                    Button(tr("Export Sample")) { ProfilesStore.saveProfiles(ProfilesStore.builtinProfiles()); profiles = ProfilesStore.loadProfiles() }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text(tr("Profile Details")).font(.headline)
                if var p = selectedProfile {
                    TextField(tr("Profile Name"), text: Binding(get: { p.name }, set: { p.name = $0; updateProfile(p) }))
                        .textFieldStyle(.roundedBorder).frame(maxWidth: 420)
                    HStack {
                        Text(tr("Plugin")).frame(width: 160, alignment: .leading).font(.system(size: 13, weight: .bold))
                        Text(tr("Version")).frame(width: 240, alignment: .leading).font(.system(size: 13, weight: .bold))
                        Spacer()
                    }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(p.versions.keys).sorted(), id: \.self) { key in
                                HStack {
                                    TextField("plugin (e.g. nodejs)", text: Binding(
                                        get: { key },
                                        set: { newKey in
                                            var v = p.versions[key] ?? ""
                                            p.versions.removeValue(forKey: key)
                                            p.versions[newKey] = v
                                            updateProfile(p)
                                        }))
                                        .textFieldStyle(.roundedBorder).frame(width: 160)
                                    TextField("version (e.g. latest:lts)", text: Binding(
                                        get: { p.versions[key] ?? "" },
                                        set: { newVal in
                                            var pp = p
                                            pp.versions[key] = newVal
                                            updateProfile(pp)
                                        }))
                                        .textFieldStyle(.roundedBorder).frame(width: 240)
                                    Button(tr("Remove")) {
                                        var pp = p; pp.versions.removeValue(forKey: key); updateProfile(pp)
                                    }
                                    Spacer()
                                }
                            }
                        }.padding(.vertical, 4)
                    }.frame(height: 320).background(.black.opacity(0.04)).clipShape(RoundedRectangle(cornerRadius: 8))
                    HStack {
                        Button(tr("Add Row")) {
                            var pp = p; pp.versions["plugin"] = "latest"; updateProfile(pp)
                        }
                        Spacer()
                        Button(tr("Save")) { ProfilesStore.saveProfiles(profiles); log.append("\nSaved profiles.") }
                    }
                } else {
                    Text(tr("Select a profile on the left to edit.")).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    // MARK: - Groups Tab
    private var groupsTab: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading) {
                HStack {
                    Text(tr("Groups")).font(.headline)
                    Spacer()
                    Button(tr("Add")) { addGroup() }
                    Button(tr("Duplicate")) { duplicateGroup() }
                    Button(tr("Delete")) { deleteGroup() }
                }
                List(selection: Binding(get: {
                    selectedGroup == nil ? Set<ProfileGroup.ID>() : [selectedGroup!.id]
                }, set: { ids in
                    if let id = ids.first { selectedGroup = groups.first(where: {$0.id == id}) }
                })) {
                    ForEach(groups) { g in
                        Text(g.name).tag(g.id)
                    }
                }.frame(width: 260, height: 420)
                HStack {
                    Button(tr("Import...")) { ProfilesStore.importGroupsViaPanel { imported in
                        if imported.isEmpty { return }
                        groups = ProfilesStore.mergeGroups(base: groups, incoming: imported); ProfilesStore.saveGroups(groups)
                        log.append("\nImported groups: \(imported.count)")
                    }}
                    Button(tr("Export...")) { ProfilesStore.exportGroupsViaPanel(groups) }
                    Button(tr("Export Sample")) { ProfilesStore.saveGroups(ProfilesStore.builtinGroups()); groups = ProfilesStore.loadGroups() }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text(tr("Group Details")).font(.headline)
                if var g = selectedGroup {
                    TextField(tr("Group Name"), text: Binding(get: { g.name }, set: { g.name = $0; updateGroup(g) }))
                        .textFieldStyle(.roundedBorder).frame(maxWidth: 420)

                    Text(tr("Included Profiles:"))
                    ScrollView {
                        VStack(alignment: .leading) {
                            ForEach(profiles, id: \.name) { p in
                                let included = g.profileNames.contains(p.name)
                                Toggle(p.name, isOn: Binding(get: { included }, set: { on in
                                    var gg = g
                                    if on { gg.profileNames.append(p.name) } else { gg.profileNames.removeAll{ $0 == p.name } }
                                    updateGroup(gg)
                                }))
                            }
                        }
                    }.frame(height: 340).background(.black.opacity(0.04)).clipShape(RoundedRectangle(cornerRadius: 8))
                    HStack {
                        Button(tr("Save")) { ProfilesStore.saveGroups(groups); log.append("\nSaved groups.") }
                        Spacer()
                    }
                } else {
                    Text(tr("Select a group on the left to edit.")).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    // MARK: - Sync Tab
    private var syncTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("Team Sync (Folder-based)")).font(.headline)
            HStack {
                Text(tr("Sync Folder:"))
                Text(syncFolder?.path ?? tr("Not set")).font(.caption).foregroundStyle(.secondary)
                Button(tr("Choose...")) {
                    ProfilesStore.chooseSyncFolder { url in
                        self.syncFolder = url
                        ProfilesStore.setSyncFolder(url)
                    }
                }
                Spacer()
            }
            HStack(spacing: 12) {
                Button(tr("Pull from Folder")) {
                    let (pc,gc) = ProfilesStore.pullFromSyncFolder()
                    self.profiles = ProfilesStore.loadProfiles()
                    self.groups = ProfilesStore.loadGroups()
                    log.append("\nPulled profiles=\(pc), groups=\(gc).")
                }
                Button(tr("Push to Folder")) {
                    let ok = ProfilesStore.pushToSyncFolder()
                    log.append("\nPushed to folder: \(ok).")
                }
                Button(tr("Open Local Files")) {
                    NSWorkspace.shared.activateFileViewerSelecting([ProfilesStore.profilesPath, ProfilesStore.groupsPath])
                }
                Spacer()
            }
            Text(tr("Tip: Put the sync folder inside Dropbox/Google Drive/git working tree to share with teammates.")).font(.caption).foregroundStyle(.secondary)
            Spacer()
        }.padding(.top, 4)
    }

    // MARK: - helpers
    private func detectCurrentSystem() {
        let detected = ProfilesStore.detectCurrentConfiguration()
        profiles.append(detected)
        ProfilesStore.saveProfiles(profiles)
        selectedProfile = detected
        log.append("\n✅ Detected system configuration: \(detected.versions.count) tools found")
    }
    
    private func addProfile() {
        let p = EnvironmentProfile(name: "New Profile", versions: ["nodejs":"latest:lts"])
        profiles.append(p); ProfilesStore.saveProfiles(profiles); selectedProfile = p
    }
    private func duplicateProfile() {
        guard let p = selectedProfile else { return }
        var np = p; np.name += " Copy"; profiles.append(np); ProfilesStore.saveProfiles(profiles); selectedProfile = np
    }
    private func deleteProfile() {
        guard let p = selectedProfile else { return }
        profiles.removeAll{ $0.id == p.id }; ProfilesStore.saveProfiles(profiles); selectedProfile = nil
    }
    private func updateProfile(_ p: EnvironmentProfile) {
        if let idx = profiles.firstIndex(where: {$0.id == p.id}) { profiles[idx] = p; ProfilesStore.saveProfiles(profiles); selectedProfile = p }
    }

    private func addGroup() {
        let g = ProfileGroup(name: "New Group", profileNames: [])
        groups.append(g); ProfilesStore.saveGroups(groups); selectedGroup = g
    }
    private func duplicateGroup() {
        guard let g = selectedGroup else { return }
        var ng = g; ng.name += " Copy"; groups.append(ng); ProfilesStore.saveGroups(groups); selectedGroup = ng
    }
    private func deleteGroup() {
        guard let g = selectedGroup else { return }
        groups.removeAll{ $0.id == g.id }; ProfilesStore.saveGroups(groups); selectedGroup = nil
    }
    private func updateGroup(_ g: ProfileGroup) {
        if let idx = groups.firstIndex(where: {$0.id == g.id}) { groups[idx] = g; ProfilesStore.saveGroups(groups); selectedGroup = g }
    }
}
