//
//  DestinationPlugin.swift
//
//
//  Created by Hao Yu on 11/15/22.
//

open class DestinationPlugin: BasePlugin, EventPlugin {
    public let type: PluginType = .destination
    private let timeline = Timeline()

    open func track(event: BaseEvent) {
    }

    open func identify(event: IdentifyEvent) {
    }

    open func groupIdentify(event: GroupIdentifyEvent) {
    }

    open func revenue(event: RevenueEvent) {
    }

    open func flush() {
    }

    public override func execute(event: BaseEvent?) -> BaseEvent? {
        // Skip this destination if it is disabled via settings
        if !enabled {
            return nil
        }
        let beforeResult = timeline.applyPlugin(pluginType: .before, event: event)
        let enrichmentResult = timeline.applyPlugin(pluginType: .enrichment, event: beforeResult)
        switch enrichmentResult {
        case let e as IdentifyEvent:
            identify(event: e)
        case let e as GroupIdentifyEvent:
            track(event: e)
        case let e as RevenueEvent:
            revenue(event: e)
        case let e?:
            track(event: e)
        default:
            break
        }
        return nil
    }
}

extension DestinationPlugin {
    var enabled: Bool {
        return true
    }

    var logger: (any Logger)? {
        return self.amplitude?.logger
    }

    @discardableResult
    func add(plugin: Plugin) -> Plugin {
        plugin.setup(amplitude: amplitude!)
        timeline.add(plugin: plugin)
        return plugin
    }

    func remove(plugin: Plugin) {
        timeline.remove(plugin: plugin)
    }

    public func apply(closure: (Plugin) -> Void) {
        timeline.apply(closure)
    }
}
