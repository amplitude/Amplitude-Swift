//
//  CrashCatcher.swift
//  Amplitude-Swift
//
//  Created by Jin Xu on 10/31/25.
//

import Foundation

/// Internal utility to catch crashes and save crash reports to disk.
/// Thread-safe, works on any thread. Register last for compatibility with other crash reporters.
class CrashCatcher {
    private static var previousExceptionHandler: (@convention(c) (NSException) -> Void)?
    private static let fatalSignals: [Int32] = [SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS, SIGPIPE, SIGTRAP]
    private static var previousSignalHandlers: [Int32: sigaction] = [:]
    private static var isRegistered: Bool = false
    private static let registrationLock = NSLock()
    
    private static let crashReportFileName = "com.amplitude.crash_report"
    private static let storagePrefix: String = "com.amplitude.crash_report"

    private static var storageDirectory: URL? {
        let fileManager = FileManager.default
        guard let baseDirectory = try? fileManager.url(for: .applicationSupportDirectory,
                                                       in: .userDomainMask,
                                                       appropriateFor: nil,
                                                       create: true) else {
            return nil
        }
        let storageDirectory = baseDirectory.appendingPathComponent(Self.storagePrefix,
                                                                    isDirectory: true)
        try? fileManager.createDirectory(at: storageDirectory,
                                         withIntermediateDirectories: true,
                                         attributes: nil)
        return storageDirectory
    }

    private static var crashReportPath: URL? {
        return storageDirectory?.appendingPathComponent(crashReportFileName)
    }
    
    /// Checks if there was a crash in the previous session
    static func checkForPreviousCrash() -> String? {
        guard let crashReportPath = crashReportPath,
              FileManager.default.fileExists(atPath: crashReportPath.path) else {
            return nil
        }
        
        do {
            let crashReason = try String(contentsOf: crashReportPath, encoding: .utf8)
            return crashReason.isEmpty ? nil : crashReason
        } catch {
            return nil
        }
    }
    
    /// Clears any saved crash report
    static func clearCrashReport() {
        guard let crashReportPath = crashReportPath else { return }
        try? FileManager.default.removeItem(at: crashReportPath)
    }
    
    /// Returns the crash report file path (for debugging)
    static func getCrashReportPath() -> String? {
        return crashReportPath?.path
    }
    
    /// Registers crash handlers. Thread-safe. Call once at app launch, after other crash reporters.
    static func register() {
        registrationLock.lock()
        defer { registrationLock.unlock() }
        
        // Prevent double registration
        guard !isRegistered else {
            return
        }
        
        // Register exception handler
        registerExceptionHandler()
        
        // Register signal handlers
        registerSignalHandlers()

        // pre check the storage directory
        let _ = storageDirectory
        
        isRegistered = true
    }
    
    /// Unregisters crash handlers and restores previous handlers
    static func unregister() {
        registrationLock.lock()
        defer { registrationLock.unlock() }
        
        guard isRegistered else {
            return
        }
        
        // Restore previous exception handler
        if let previous = previousExceptionHandler {
            NSSetUncaughtExceptionHandler(previous)
        } else {
            NSSetUncaughtExceptionHandler(nil)
        }
        
        // Restore previous signal handlers
        for (signal, var action) in previousSignalHandlers {
            sigaction(signal, &action, nil)
        }
        previousSignalHandlers.removeAll()
        previousExceptionHandler = nil
        
        isRegistered = false
    }
    
    private static func registerExceptionHandler() {
        previousExceptionHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler(handleException)
    }
    
    private static func registerSignalHandlers() {
        for signal in fatalSignals {
            var action = sigaction()
            var oldAction = sigaction()
            
            // Get current handler
            sigaction(signal, nil, &oldAction)
            previousSignalHandlers[signal] = oldAction
            
            // Set up new handler
            action.__sigaction_u.__sa_sigaction = handleSignal
            action.sa_flags = SA_SIGINFO
            sigemptyset(&action.sa_mask)
            
            sigaction(signal, &action, nil)
        }
    }
    
    private static let handleException: @convention(c) (NSException) -> Void = { exception in
        let reason = formatExceptionReason(exception)
        
        // Save crash report to disk for next launch
        saveCrashReport(reason)
        
        // Call previous handler if it exists (e.g., Crashlytics, PLCrashReporter)
        // They will handle termination
        if let previous = previousExceptionHandler {
            previous(exception)
            // If previous handler returns (shouldn't happen but just in case), terminate
            abort()
        } else {
            // No previous handler, we need to terminate
            abort()
        }
    }
    
    private static let handleSignal: @convention(c) (Int32, UnsafeMutablePointer<__siginfo>?, UnsafeMutableRawPointer?) -> Void = { sig, info, context in
        let reason = formatSignalReason(sig, info: info)
        
        // Save crash report to disk for next launch
        saveCrashReport(reason)
        
        // Call previous handler if it exists (e.g., Crashlytics, PLCrashReporter)
        let oldHandler = previousSignalHandlers[sig]
        if let handler = oldHandler?.__sigaction_u.__sa_sigaction {
            // Previous handler with sigaction exists, call it
            handler(sig, info, context)
            // If it returns, fall through to default termination
        } else if oldHandler?.__sigaction_u.__sa_handler != nil {
            // Previous simple handler exists, call it if not default or ignore
            let handler = oldHandler?.__sigaction_u.__sa_handler
            // Check if it's not SIG_DFL or SIG_IGN by comparing raw values
            let handlerValue = unsafeBitCast(handler, to: Int.self)
            let sigDflValue = unsafeBitCast(SIG_DFL, to: Int.self)
            let sigIgnValue = unsafeBitCast(SIG_IGN, to: Int.self)
            
            if handlerValue != sigDflValue && handlerValue != sigIgnValue, let validHandler = handler {
                validHandler(sig)
                // If it returns, fall through to default termination
            }
        }
        
        // Reset to default handler and re-raise to terminate properly
        signal(sig, SIG_DFL)
        raise(sig)
    }
    
    private static func saveCrashReport(_ reason: String) {
        guard let crashReportPath = crashReportPath else { return }
        
        do {
            let timestamp = Date()
            let formatter = ISO8601DateFormatter()
            let timestampString = formatter.string(from: timestamp)
            
            let reportContent = """
            Crash Report
            Timestamp: \(timestampString)
            
            \(reason)
            """
            
            // Write atomically and synchronously to ensure it completes before process terminates
            guard let data = reportContent.data(using: .utf8) else { return }
            
            // Write directly to ensure it's synchronous
            try data.write(to: crashReportPath, options: [.atomic])
            
            // Force sync to disk
            let fileHandle = try FileHandle(forReadingFrom: crashReportPath)
            try fileHandle.synchronize()
            try fileHandle.close()
        } catch {
            // Silent fail - we're in a crash handler, can't do much
        }
    }
    
    private static func formatExceptionReason(_ exception: NSException) -> String {
        var reason = "Uncaught Exception: \(exception.name.rawValue)"
        
        if let exceptionReason = exception.reason {
            reason += " - \(exceptionReason)"
        }
        
        if !exception.callStackSymbols.isEmpty {
            reason += "\nCall Stack:\n"
            reason += exception.callStackSymbols.joined(separator: "\n")
        }
        
        return reason
    }
    
    private static func formatSignalReason(_ signal: Int32, info: UnsafeMutablePointer<__siginfo>?) -> String {
        let signalName = getSignalName(signal)
        var reason = "Fatal Signal: \(signalName) (\(signal))"
        
        if let info = info?.pointee {
            reason += " - Code: \(info.si_code)"
            reason += ", Address: \(String(format: "0x%llx", UInt(bitPattern: info.si_addr)))"
        }
        
        // Add stack trace
        let stackTrace = Thread.callStackSymbols
        if !stackTrace.isEmpty {
            reason += "\nCall Stack:\n"
            reason += stackTrace.joined(separator: "\n")
        }
        
        return reason
    }
    
    private static func getSignalName(_ signal: Int32) -> String {
        switch signal {
        case SIGABRT: return "SIGABRT"
        case SIGILL: return "SIGILL"
        case SIGSEGV: return "SIGSEGV"
        case SIGFPE: return "SIGFPE"
        case SIGBUS: return "SIGBUS"
        case SIGPIPE: return "SIGPIPE"
        case SIGTRAP: return "SIGTRAP"
        default: return "UNKNOWN"
        }
    }
}
