import Foundation

internal protocol ApplicationLifecycleObserver: AnyObject {
    func applicationDidFinishLaunching()
    func applicationWillEnterForeground(timestamp: Int64, fromBackground: Bool)
    func applicationDidEnterBackground(timestamp: Int64)
}

extension ApplicationLifecycleObserver {
    func applicationDidFinishLaunching() {}
}

/// Owns platform lifecycle notifications and delivers them without retaining consumers.
internal class ApplicationLifecycle: NSObject {
    private struct WeakObserver {
        weak var value: (any ApplicationLifecycleObserver)?
    }

    private let lock = NSLock()
    private var observers: [WeakObserver] = []

    func addObserver(_ observer: any ApplicationLifecycleObserver) {
        lock.withLock {
            observers.removeAll { $0.value == nil }
            guard !observers.contains(where: { $0.value === observer }) else { return }
            observers.append(WeakObserver(value: observer))
        }
    }

    /// Called after all consumers are registered and SDK initialization is complete.
    func start() {}

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func didFinishLaunching() {
        notify { $0.applicationDidFinishLaunching() }
    }

    func enterForeground(fromBackground: Bool = false) {
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        notify { $0.applicationWillEnterForeground(timestamp: timestamp, fromBackground: fromBackground) }
    }

    func enterBackground() {
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        notify { $0.applicationDidEnterBackground(timestamp: timestamp) }
    }

    private func notify(_ callback: (any ApplicationLifecycleObserver) -> Void) {
        let currentObservers = lock.withLock {
            observers.removeAll { $0.value == nil }
            return observers.compactMap { $0.value }
        }
        // Observers choose their execution queue; never invoke them while holding the lock.
        currentObservers.forEach(callback)
    }
}
