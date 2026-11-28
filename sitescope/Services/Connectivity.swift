import Foundation
import Network

/// Reports whether the phone has a usable network path, on the main actor. Sync starts when the path comes back;
/// whether the server itself is reachable is learned from the requests.
@MainActor final class Connectivity {
    private let monitor = NWPathMonitor()
    private(set) var isOnline = true
    /// Called with the new state whenever it changes.
    var onChange: (@MainActor (Bool) -> Void)?

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in
                guard let self, self.isOnline != online else { return }
                self.isOnline = online
                self.onChange?(online)
            }
        }
        monitor.start(queue: DispatchQueue(label: "sitescope.connectivity"))
    }
    func stop() { monitor.cancel() }
}
