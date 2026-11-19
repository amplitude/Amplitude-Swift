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
/// Observer delivery order is unspecified; consumers own any sequencing they require.
internal class ApplicationLifecycle: NSObject {
    private let lock = NSLock()
    private let observers = NSHashTable<AnyObject>(options: [.weakMemory, .objectPointerPersonality])

    func addObserver(_ observer: any ApplicationLifecycleObserver) {
        lock.withLock {
            observers.add(observer)
        }
    }

    /// Called after all consumers are registered and SDK initialization is complete.
    func start() {}

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
            observers.allObjects.compactMap { $0 as? any ApplicationLifecycleObserver }
        }
        // Observers choose their execution queue; never invoke them while holding the lock.
        currentObservers.forEach(callback)
    }
}
