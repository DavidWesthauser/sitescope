import SwiftUI
import UIKit
import UniformTypeIdentifiers

extension UTType {
    static let sitescopeProject = UTType(exportedAs: "de.davidwesthauser.sitescope.project", conformingTo: .data)
}

struct ProjectFileShareButton: View {
    let project: Project
    @EnvironmentObject private var store: Store
    @State private var shareItem: ShareItem?
    @State private var exportedFile: URL?

    private struct ShareItem: Identifiable {
        let url: URL
        var id: URL { url }
    }

    var body: some View {
        Button("Export project", systemImage: "square.and.arrow.up") {
            store.run {
                let url = try await store.exportProjectFile(project)
                exportedFile = url
                shareItem = ShareItem(url: url)
            }
        }
        .disabled(store.busy || shareItem != nil)
        .accessibilityIdentifier("project.export")
        .background {
            ProjectActivityPresenter(url: shareItem?.url) {
                shareItem = nil
                removeTemporaryExport()
            }.frame(width: 0, height: 0)
        }
    }

    private func removeTemporaryExport() {
        guard let url = exportedFile else { return }
        exportedFile = nil
        guard let directory = ownedExportDirectory(for: url) else { return }
        // Best effort: only the uniquely owned export directory, never imported/user documents.
        try? FileManager.default.removeItem(at: directory)
    }

    private func ownedExportDirectory(for url: URL) -> URL? {
        guard url.isFileURL, url.pathExtension.lowercased() == "sitescope" else { return nil }
        let file = url.standardizedFileURL.resolvingSymlinksInPath()
        let directory = file.deletingLastPathComponent()
        let temporaryRoot = FileManager.default.temporaryDirectory.standardizedFileURL.resolvingSymlinksInPath()
        let prefix = "sitescope-Export-"
        guard directory.deletingLastPathComponent().path == temporaryRoot.path,
              directory.lastPathComponent.hasPrefix(prefix),
              UUID(uuidString: String(directory.lastPathComponent.dropFirst(prefix.count))) != nil else { return nil }
        return directory
    }
}

/// Present the activity controller natively so its close action owns dismissal.
private struct ProjectActivityPresenter: UIViewControllerRepresentable {
    let url: URL?
    let onFinish: @MainActor () -> Void

    func makeUIViewController(context: Context) -> Presenter { Presenter() }
    func updateUIViewController(_ controller: Presenter, context: Context) {
        controller.requestedURL = url
        controller.onFinish = onFinish
        controller.presentIfReady()
    }

    @MainActor final class Presenter: UIViewController, UIPopoverPresentationControllerDelegate {
        var requestedURL: URL?
        var onFinish: (() -> Void)?
        private var activeURL: URL?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            presentIfReady()
        }
        func presentIfReady() {
            guard let url = requestedURL, activeURL == nil,
                  viewIfLoaded?.window != nil, presentedViewController == nil else { return }
            activeURL = url
            let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            activity.completionWithItemsHandler = { [weak self] _, _, _, _ in
                Task { @MainActor in self?.finish() }
            }
            activity.popoverPresentationController?.sourceView = view
            activity.popoverPresentationController?.sourceRect = view.bounds
            activity.popoverPresentationController?.delegate = self
            present(activity, animated: true)
            activity.presentationController?.delegate = self
        }
        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) { finish() }
        func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) { finish() }
        private func finish() {
            guard activeURL != nil else { return }
            requestedURL = nil
            // Keep the presentation guard until SwiftUI has consumed completion.
            onFinish?()
            activeURL = nil
        }
    }
}
