import Foundation

internal protocol ApplicationLifecycleObserver: AnyObject {
    func applicationDidFinishLaunching()
    func applicationDidBecomeActive(launch: Bool)
    func applicationWillEnterForeground(timestamp: Int64, fromBackground: Bool)
    func applicationDidEnterBackground(timestamp: Int64)
}

extension ApplicationLifecycleObserver {
    func applicationDidFinishLaunching() {}
    func applicationDidBecomeActive(launch: Bool) {}
}

/// Owns platform lifecycle notifications and delivers them without retaining consumers.
/// Observer delivery order is unspecified; consumers own any sequencing they require.
internal class ApplicationLifecycle: NSObject {
    private let lock = NSLock()
    private var isObserving = false
    private let observers = NSHashTable<AnyObject>(options: [.weakMemory, .objectPointerPersonality])

    func addObserver(_ observer: any ApplicationLifecycleObserver) {
        lock.withLock {
            observers.add(observer)
        }
    }

    /// Called once consumers are registered, before the remaining SDK plugins are set up.
    @discardableResult
    func start() -> Bool {
        lock.withLock {
            guard !isObserving else { return false }
            startObserving()
            isObserving = true
            return true
        }
    }

    /// Registers platform notifications once. Startup reconciliation stays in start().
    func startObserving() {}

    func didFinishLaunching() {
        notify { $0.applicationDidFinishLaunching() }
    }

    /// Initial activation, including initialization in an already-active app.
    func becomeActive(launch: Bool) {
        notify { $0.applicationDidBecomeActive(launch: launch) }
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
