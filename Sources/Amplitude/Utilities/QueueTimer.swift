//
//  QueueTimer.swift
//
//
//  Created by Marvin Liu on 11/29/22.
//

import Foundation

/// Call start() and stop() on the timer's serial queue.
internal final class QueueTimer {
    private let source: DispatchSourceTimer
    private(set) var isRunning = true

    init(interval: TimeInterval, once: Bool = false, queue: DispatchQueue = .main, handler: @escaping () -> Void) {
        source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now() + interval, repeating: once ? .infinity : interval)
        source.setEventHandler(handler: handler)
        source.activate()
    }

    deinit {
        source.cancel()
        if !isRunning { source.resume() } // Balance the suspension before releasing the source.
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        source.resume()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        source.suspend()
    }
}

extension TimeInterval {
    static func milliseconds(_ value: Int) -> TimeInterval {
        return TimeInterval(Double(value) / 1000.0)
    }

    static func seconds(_ value: Int) -> TimeInterval {
        return TimeInterval(value)
    }

}
