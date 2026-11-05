import SwiftUI
@main struct sitescopeApp: App {
    @StateObject private var store = Store()
    @State private var importedProjectName: String?
    var body: some Scene {
        WindowGroup {
            Group {
                if store.signedIn { ProjectDashboard() }
                else if store.unreadableLocalData != nil { LocalDataRecoveryView() }
                else { AuthenticationView() }
            }
                .environmentObject(store)
                .tint(.teal)
                .onOpenURL { url in
                    guard !store.busy else {
                        store.error = "Finish the current operation, then open the project file again."
                        return
                    }
                    store.run { importedProjectName = try await store.importProjectFile(from: url).name }
                }
                .alert(store.error == nil && importedProjectName != nil ? "Project imported" : "sitescope", isPresented: Binding(get: { store.error != nil || importedProjectName != nil }, set: { if !$0 { store.error = nil; importedProjectName = nil } })) {
                    Button("OK") { store.error = nil; importedProjectName = nil }
                } message: {
                    Text(store.error ?? "“\(importedProjectName ?? "Project")” is now an editable copy in Projects. Later changes are not synchronized.")
                }
                .overlay { if store.busy { ZStack { Color.black.opacity(0.12).ignoresSafeArea();ProgressView("Working…").padding(24).background(.regularMaterial,in:RoundedRectangle(cornerRadius:16)) } } }
        }
    }
}
