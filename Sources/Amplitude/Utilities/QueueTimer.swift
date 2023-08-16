//
//  QueueTimer.swift
//
//
//  Created by Marvin Liu on 11/29/22.
//

import Foundation

internal class QueueTimer {
    enum State {
        case suspended
        case resumed
    }

    let interval: TimeInterval
    let timer: DispatchSourceTimer
    let queue: DispatchQueue
    let handler: () -> Void

    @Atomic var state: State = .suspended

    static var timers = [QueueTimer]()

    static func schedule(interval: TimeInterval, queue: DispatchQueue = .main, handler: @escaping () -> Void) {
        let timer = QueueTimer(interval: interval, queue: queue, handler: handler)
        Self.timers.append(timer)
    }

    /// `DispatchQueue` appropriate for the environment being executed.
    ///
    /// When running on a server (in a headless/windowless state), the `.main` `DispatchQueue`
    /// may not execute tasks that are enqueued to it. Essentially we can't count on the CGD event loop
    /// like we typically do in iOS/tvOS/watchOS/macOS applications.
    static func queue(runningOnServer: Bool) -> DispatchQueue {
        runningOnServer ? .global(qos: .utility) : .main
    }

    init(interval: TimeInterval, once: Bool = false, queue: DispatchQueue = .main, handler: @escaping () -> Void) {
        self.interval = interval
        self.queue = queue
        self.handler = handler

        timer = DispatchSource.makeTimerSource(flags: [], queue: queue)
        timer.schedule(deadline: .now() + self.interval, repeating: once ? .infinity : self.interval)
        timer.setEventHandler { [weak self] in
            self?.handler()
        }
        resume()
    }

    deinit {
        timer.setEventHandler {
            // do nothing ...
        }
        // if timer is suspended, we must resume if we're going to cancel.
        timer.cancel()
        resume()
    }

    func suspend() {
        if state == .suspended {
            return
        }
        state = .suspended
        timer.suspend()
    }

    func resume() {
        if state == .resumed {
            return
        }
        state = .resumed
        timer.resume()
    }
}

extension TimeInterval {
    static func milliseconds(_ value: Int) -> TimeInterval {
        return TimeInterval(value / 1000)
    }

    static func seconds(_ value: Int) -> TimeInterval {
        return TimeInterval(value)
    }

    static func hours(_ value: Int) -> TimeInterval {
        return TimeInterval(60 * value)
    }

    static func days(_ value: Int) -> TimeInterval {
        return TimeInterval((60 * value) * 24)
    }
}
