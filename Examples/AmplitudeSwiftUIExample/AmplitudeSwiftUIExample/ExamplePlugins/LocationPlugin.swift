import AmplitudeSwift
import Foundation
import CoreLocation

/// Plugin to collect location data. Users will be prompted if authorization status is undetermined.
/// This plugin example currently supports iOS 14+ only.
/// Don't forget to add "NSLocationWhenInUseUsageDescription" with a description to your Info.plist.
class LocationPlugin: NSObject, Plugin, CLLocationManagerDelegate {
    let type = PluginType.enrichment
    weak var amplitude: Amplitude? = nil
    private var locationManager: CLLocationManager? = nil
    private var location: CLLocation? = nil

    func setup(amplitude: Amplitude) {
        self.amplitude = amplitude

        locationManager = CLLocationManager()
        locationManager!.delegate = self
        startUpdatingLocation()
    }

    func execute(event: BaseEvent) -> BaseEvent? {
        if let location {
            event.locationLat = location.coordinate.latitude
            event.locationLng = location.coordinate.longitude
        }
        return event
    }

    func startUpdatingLocation() {
        if !isAuthorized() {
            locationManager?.requestWhenInUseAuthorization()
        } else {
            locationManager?.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if locations.count > 0 {
            location = locations.first
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        amplitude?.logger?.error(message: error.localizedDescription)
        clearReferences()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            startUpdatingLocation()
            break
        case .notDetermined:
            break
        case .denied, .restricted:
            clearReferences()
        default:
            clearReferences()
        }
    }

    func clearReferences() {
        locationManager?.stopUpdatingLocation()
        locationManager = nil
    }

    func isAuthorizationDenied() -> Bool {
        let status = locationManager?.authorizationStatus
        return status == .denied
    }

    func isAuthorized() -> Bool {
        let status = locationManager?.authorizationStatus
        return status == .authorizedAlways || status == .authorizedWhenInUse
    }
}
