/// Serializes analytics lifecycle work independently of other lifecycle observers.
internal class ApplicationLifecyclePlugin: UtilityPlugin, ApplicationLifecycleObserver {
    override func setup(amplitude: Amplitude) {
        super.setup(amplitude: amplitude)
        amplitude.appLifecycle.addObserver(self)
    }

    final func applicationDidFinishLaunching() {
        amplitude?.trackingQueue.async { [self] in
            didFinishLaunching()
        }
    }

    final func applicationWillEnterForeground(timestamp: Int64, fromBackground: Bool) {
        amplitude?.trackingQueue.async { [self] in
            willEnterForeground(timestamp: timestamp, fromBackground: fromBackground)
        }
    }

    final func applicationDidEnterBackground(timestamp: Int64) {
        amplitude?.trackingQueue.async { [self] in
            didEnterBackground(timestamp: timestamp)
        }
    }

    func didFinishLaunching() {}

    func willEnterForeground(timestamp: Int64, fromBackground: Bool) {
        amplitude?.onEnterForeground(timestamp: timestamp)
    }

    func didEnterBackground(timestamp: Int64) {
        amplitude?.onExitForeground(timestamp: timestamp)
    }
}
