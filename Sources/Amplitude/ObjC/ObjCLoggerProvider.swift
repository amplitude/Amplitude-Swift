import Foundation

public typealias ObjCLoggerProvider = (Int, String) -> Void

class ObjCLoggerProviderWrapper: Logger {
    public typealias LogLevel = LogLevelEnum
    public var logLevel: Int

    private let logProvider: ObjCLoggerProvider

    init(
        logLevel: LogLevelEnum,
        logProvider: @escaping ObjCLoggerProvider
    ) {
        self.logLevel = logLevel.rawValue
        self.logProvider = logProvider
    }

    func error(message: String) {
        if logLevel >= LogLevelEnum.ERROR.rawValue {
            logProvider(logLevel, message)
        }
    }

    func warn(message: String) {
        if logLevel >= LogLevelEnum.WARN.rawValue {
            logProvider(logLevel, message)
        }
    }

    func log(message: String) {
        if logLevel >= LogLevelEnum.LOG.rawValue {
            logProvider(logLevel, message)
        }
    }

    func debug(message: String) {
        if logLevel >= LogLevelEnum.DEBUG.rawValue {
            logProvider(logLevel, message)
        }
    }
}
