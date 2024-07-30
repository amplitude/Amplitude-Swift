import Foundation

public class DefaultEventUtils {
    private weak var amplitude: Amplitude?

    public init(amplitude: Amplitude) {
        self.amplitude = amplitude
    }

    public func trackAppUpdatedInstalledEvent() {
        let info = Bundle.main.infoDictionary
        let currentBuild = info?["CFBundleVersion"] as? String
        let currentVersion = info?["CFBundleShortVersionString"] as? String
        let previousBuild: String? = amplitude?.storage.read(key: StorageKey.APP_BUILD)
        let previousVersion: String? = amplitude?.storage.read(key: StorageKey.APP_VERSION)

        if amplitude?.configuration.autocapture.appLifecycles ?? false {
            let lastEventTime: Int64? = amplitude?.storage.read(key: StorageKey.LAST_EVENT_TIME)
            if lastEventTime == nil {
                self.amplitude?.track(eventType: Constants.AMP_APPLICATION_INSTALLED_EVENT, eventProperties: [
                    Constants.AMP_APP_BUILD_PROPERTY: currentBuild ?? "",
                    Constants.AMP_APP_VERSION_PROPERTY: currentVersion ?? "",
                ])
            } else if currentBuild != previousBuild {
                self.amplitude?.track(eventType: Constants.AMP_APPLICATION_UPDATED_EVENT, eventProperties: [
                    Constants.AMP_APP_BUILD_PROPERTY: currentBuild ?? "",
                    Constants.AMP_APP_VERSION_PROPERTY: currentVersion ?? "",
                    Constants.AMP_APP_PREVIOUS_BUILD_PROPERTY: previousBuild ?? "",
                    Constants.AMP_APP_PREVIOUS_VERSION_PROPERTY: previousVersion ?? "",
                ])
            }
        }

        if currentBuild != previousBuild {
            try? amplitude?.storage.write(key: StorageKey.APP_BUILD, value: currentBuild)
        }
        if currentVersion != previousVersion {
            try? amplitude?.storage.write(key: StorageKey.APP_VERSION, value: currentVersion)
        }
    }

}
