@testable import Amplitude_Swift

class TestEnrichmentPlugin: Plugin {
    let type: PluginType
    var amplitude: Amplitude?
    let trackCompletion: (() -> Bool)?

    init(trackCompletion: (() -> Bool)? = nil) {
        self.type = PluginType.enrichment
        self.trackCompletion = trackCompletion
    }

    func setup(amplitude: Amplitude) {
        self.amplitude = amplitude
    }

    func execute(event: BaseEvent?) -> BaseEvent? {
        var returnEvent: BaseEvent? = event
        if let completion = trackCompletion {
            if !completion() {
                returnEvent = nil
            }
        }
        return returnEvent
    }
}

class OutputReaderPlugin: Plugin {
    var type: PluginType
    var amplitude: Amplitude?

    var lastEvent: BaseEvent?

    init() {
        self.type = .destination
    }

    func setup(amplitude: Amplitude) {
        self.amplitude = amplitude
    }

    func execute(event: BaseEvent?) -> BaseEvent? {
        lastEvent = event
        return event
    }
}
