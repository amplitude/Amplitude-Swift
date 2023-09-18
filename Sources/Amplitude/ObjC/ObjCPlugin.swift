import Foundation

@objc(AMPPlugin)
public class ObjCPlugin: NSObject {
    internal let type: PluginType
    internal let setup: ((ObjCAmplitude) -> Void)?
    internal let execute: (ObjCBaseEvent) -> ObjCBaseEvent?

    @objc(init:setup:execute:)
    public init(
        type: PluginType,
        setup: @escaping (ObjCAmplitude) -> Void,
        execute: @escaping (ObjCBaseEvent) -> ObjCBaseEvent?
    ) {
        self.type = type
        self.setup = setup
        self.execute = execute
    }

    @objc(init:execute:)
    public init(type: PluginType, execute: @escaping (ObjCBaseEvent) -> ObjCBaseEvent?) {
        self.type = type
        self.setup = nil
        self.execute = execute
    }
}

class ObjCPluginWrapper: Plugin {
    weak var amplitude: ObjCAmplitude?
    let type: PluginType
    let wrapped: ObjCPlugin

    init(amplitude: ObjCAmplitude, wrapped: ObjCPlugin) {
        self.amplitude = amplitude
        self.type = wrapped.type
        self.wrapped = wrapped
    }

    func setup(amplitude: Amplitude) {
        guard let amplitude = self.amplitude else { return }
        wrapped.setup?(amplitude)
    }

    func execute(event: BaseEvent) -> BaseEvent? {
        wrapped.execute(ObjCBaseEvent(event: event))?.event
    }
}
