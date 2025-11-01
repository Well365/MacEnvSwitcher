import SwiftUI

struct EnvironmentManagerView: View {
    @StateObject private var vm = BootstrapViewModel()
    @State private var showCreateEnvironment = false
    @State private var showEditEnvironment = false
    @State private var editingProfile: EnvironmentProfile? = nil
    @State private var selectedProfileForAction: EnvironmentProfile? = nil
    @State private var showDeleteConfirmation = false
    @State private var refreshID = UUID()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Toolbar
            HStack {
                Text(tr("Environment Manager"))
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(tr("New Environment")) {
                    showCreateEnvironment = true
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: {
                    vm.reloadProfiles()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header with current active environment
                    currentEnvironmentHeader
                    
                    Divider()
                    
                    // Quick actions
                    quickActionsBar
                    
                    Divider()
                    
                    // Environment list
                    environmentsList
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
        }
        .id(refreshID)
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            refreshID = UUID()
        }
        .sheet(isPresented: $showCreateEnvironment) {
            EnvironmentEditorView(
                isPresented: $showCreateEnvironment,
                profile: .constant(EnvironmentProfile(name: "", description: "", versions: [:])),
                isNew: true,
                onSave: { profile in
                    vm.addEnvironment(profile)
                }
            )
            .frame(minWidth: 700, minHeight: 500)
        }
        .sheet(isPresented: $showEditEnvironment) {
            if let profile = editingProfile {
                EnvironmentEditorView(
                    isPresented: $showEditEnvironment,
                    profile: .constant(profile),
                    isNew: false,
                    onSave: { updatedProfile in
                        vm.updateEnvironment(updatedProfile)
                    }
                )
                .frame(minWidth: 700, minHeight: 500)
            }
        }
        .alert(tr("Delete Environment"), isPresented: $showDeleteConfirmation) {
            Button(tr("Cancel"), role: .cancel) { }
            Button(tr("Delete"), role: .destructive) {
                if let profile = selectedProfileForAction {
                    vm.deleteEnvironment(profile.name)
                }
            }
        } message: {
            if let profile = selectedProfileForAction {
                Text(tr("Are you sure you want to delete environment '\(profile.name)'? This action cannot be undone."))
            }
        }
    }
    
    private var currentEnvironmentHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tr("Current Active Environment")).font(.headline)
            
            if let current = vm.currentActiveProfile {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(current.name).font(.title2).bold().foregroundColor(.green)
                        if !current.description.isEmpty {
                            Text(current.description).font(.caption).foregroundColor(.secondary)
                        }
                        Text(tr("Active since: \(current.lastUsed?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown")"))
                            .font(.caption2).foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(tr("Deactivate")) {
                        vm.deactivateCurrentEnvironment()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                HStack {
                    VStack(alignment: .leading) {
                        Text(tr("No Active Environment")).font(.title2).foregroundColor(.orange)
                        Text(tr("Using system default versions")).font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    private var quickActionsBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tr("Quick Switch")).font(.headline)
            
            HStack(spacing: 12) {
                Menu(tr("Switch to Environment")) {
                    ForEach(vm.profiles.filter { !$0.isActive }, id: \.self) { profile in
                        Button(action: {
                            vm.switchToEnvironment(profile)
                        }) {
                            VStack(alignment: .leading) {
                                Text(profile.name)
                                if !profile.description.isEmpty {
                                    Text(profile.description).font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    if vm.profiles.filter({ !$0.isActive }).isEmpty {
                        Text(tr("No other environments available")).foregroundColor(.secondary)
                    }
                }
                .menuStyle(.borderlessButton)
                .disabled(vm.profiles.filter { !$0.isActive }.isEmpty)
                
                Button(tr("Reload All")) {
                    vm.reloadProfiles()
                }
                .buttonStyle(.bordered)
                
                Button(tr("Export Samples")) {
                    vm.exportProfilesSample()
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var environmentsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tr("All Environments")).font(.headline)
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(vm.profiles, id: \.self) { profile in
                        EnvironmentCard(
                            profile: profile,
                            isActive: profile.isActive,
                            onSwitch: {
                                vm.switchToEnvironment(profile)
                            },
                            onEdit: {
                                editingProfile = profile
                                showEditEnvironment = true
                            },
                            onDelete: {
                                selectedProfileForAction = profile
                                showDeleteConfirmation = true
                            }
                        )
                    }
                }
            }
        }
    }
}

struct EnvironmentCard: View {
    let profile: EnvironmentProfile
    let isActive: Bool
    let onSwitch: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(profile.name).font(.headline)
                        if isActive {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                        }
                    }
                    if !profile.description.isEmpty {
                        Text(profile.description).font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                
                // Action buttons
                HStack(spacing: 8) {
                    if !isActive {
                        Button(tr("Switch")) {
                            onSwitch()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    Button(tr("Edit")) {
                        onEdit()
                    }
                    .buttonStyle(.bordered)
                    
                    Button(tr("Delete")) {
                        onDelete()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
            }
            
            // Language versions
            if !profile.versions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("Language Versions:")).font(.caption).bold()
                    ForEach(profile.versions.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack {
                            Text(key).font(.caption).foregroundColor(.primary)
                            Spacer()
                            Text(value).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Virtual environments
            if !profile.virtualEnvs.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("Virtual Environments:")).font(.caption).bold()
                    ForEach(profile.virtualEnvs.sorted(by: { $0.key < $1.key }), id: \.key) { key, venv in
                        HStack {
                            Text("\(key):").font(.caption).foregroundColor(.primary)
                            Text("\(venv.type.displayName) - \(venv.name)").font(.caption).foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
            }
            
            // Environment variables
            if !profile.environmentVars.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("Environment Variables:")).font(.caption).bold()
                    ForEach(profile.environmentVars.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack {
                            Text(key).font(.caption).foregroundColor(.primary)
                            Spacer()
                            Text(value).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Metadata
            HStack {
                Text(tr("Created: \(profile.createdAt.formatted(date: .abbreviated, time: .omitted))"))
                    .font(.caption2).foregroundColor(.secondary)
                Spacer()
                if let lastUsed = profile.lastUsed {
                    Text(tr("Last used: \(lastUsed.formatted(date: .abbreviated, time: .shortened))"))
                        .font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(isActive ? Color.green.opacity(0.1) : Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? Color.green : Color.clear, lineWidth: 2)
        )
    }
}

#Preview {
    EnvironmentManagerView()
}
