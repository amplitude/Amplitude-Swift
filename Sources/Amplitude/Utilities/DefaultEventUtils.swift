import Foundation

public class DefaultEventUtils {

    private static var instanceNamesThatSentAppUpdatedInstalled: Set<String> = []

    private weak var amplitude: Amplitude?

    public init(amplitude: Amplitude) {
        self.amplitude = amplitude
    }

    public func trackAppUpdatedInstalledEvent() {
        guard let amplitude = amplitude else {
            return
        }

        let info = Bundle.main.infoDictionary
        let currentBuild = info?["CFBundleVersion"] as? String
        let currentVersion = info?["CFBundleShortVersionString"] as? String
        let previousBuild: String? = amplitude.storage.read(key: StorageKey.APP_BUILD)
        let previousVersion: String? = amplitude.storage.read(key: StorageKey.APP_VERSION)

        if currentBuild != previousBuild {
            try? amplitude.storage.write(key: StorageKey.APP_BUILD, value: currentBuild)
        }
        if currentVersion != previousVersion {
            try? amplitude.storage.write(key: StorageKey.APP_VERSION, value: currentVersion)
        }

        guard amplitude.configuration.autocapture.contains(.appLifecycles),
              !Self.instanceNamesThatSentAppUpdatedInstalled.contains(amplitude.configuration.instanceName) else {
            return
        }
        // Only send one app installed / updated event per instance name, no matter how many times we are
        // reinitialized
        Self.instanceNamesThatSentAppUpdatedInstalled.insert(amplitude.configuration.instanceName)

        if previousBuild == nil || previousVersion == nil {
            amplitude.track(eventType: Constants.AMP_APPLICATION_INSTALLED_EVENT, eventProperties: [
                Constants.AMP_APP_BUILD_PROPERTY: currentBuild ?? "",
                Constants.AMP_APP_VERSION_PROPERTY: currentVersion ?? "",
            ])
        } else if currentBuild != previousBuild || currentVersion != previousVersion {
            amplitude.track(eventType: Constants.AMP_APPLICATION_UPDATED_EVENT, eventProperties: [
                Constants.AMP_APP_BUILD_PROPERTY: currentBuild ?? "",
                Constants.AMP_APP_VERSION_PROPERTY: currentVersion ?? "",
                Constants.AMP_APP_PREVIOUS_BUILD_PROPERTY: previousBuild ?? "",
                Constants.AMP_APP_PREVIOUS_VERSION_PROPERTY: previousVersion ?? "",
            ])
        }
    }

    func trackAppOpenedEvent(fromBackground: Bool = false) {
        guard let amplitude = amplitude,
              amplitude.configuration.autocapture.contains(.appLifecycles) else {
            return
        }

        let info = Bundle.main.infoDictionary
        let currentBuild = info?["CFBundleVersion"] as? String
        let currentVersion = info?["CFBundleShortVersionString"] as? String
        self.amplitude?.track(eventType: Constants.AMP_APPLICATION_OPENED_EVENT, eventProperties: [
            Constants.AMP_APP_BUILD_PROPERTY: currentBuild ?? "",
            Constants.AMP_APP_VERSION_PROPERTY: currentVersion ?? "",
            Constants.AMP_APP_FROM_BACKGROUND_PROPERTY: fromBackground,
        ])
    }
}
