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
    private let lock = NSLock()
    private let observers = NSMapTable<AnyObject, NSNumber>(
        keyOptions: [.weakMemory, .objectPointerPersonality], valueOptions: .strongMemory)
    private var nextObserverIndex = 0

    func addObserver(_ observer: any ApplicationLifecycleObserver) {
        lock.withLock {
            guard observers.object(forKey: observer) == nil else { return }
            observers.setObject(NSNumber(value: nextObserverIndex), forKey: observer)
            nextObserverIndex += 1
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
            // NSMapTable is unordered. Preserve registration order for session and autocapture callbacks.
            observers.keyEnumerator().allObjects.compactMap { key -> (observer: any ApplicationLifecycleObserver, index: Int)? in
                guard let observer = key as? any ApplicationLifecycleObserver,
                      let index = observers.object(forKey: observer) else { return nil }
                return (observer, index.intValue)
            }.sorted { $0.index < $1.index }.map(\.observer)
        }
        // Observers choose their execution queue; never invoke them while holding the lock.
        currentObservers.forEach(callback)
    }
}
