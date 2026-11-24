//
//  EventPipelineTests.swift
//
//
//  Created by Marvin Liu on 11/30/22.
//

import XCTest

#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@testable import AmplitudeSwift

final class EventPipelineTests: XCTestCase {
    private static let FLUSH_INTERVAL_SECONDS = 10.0

    // Wait budgets here are deliberately loose (10 s; 15 s where the SDK's own 1 s + 2 s retry
    // backoff is being waited out). Everything goes through FakeHttpClient in-process, so a
    // green run returns as soon as the expectation fires; the budget only decides how long a
    // genuinely broken run takes to report. The original 1-2 s budgets were exceeded on a
    // 3-vCPU CI simulator, and the indexing that followed turned that into a bundle crash.

    private var configuration: Configuration!
    private var pipeline: EventPipeline!
    private var httpClient: FakeHttpClient!
    private var storage: PersistentStorage!

    override func setUp() {
        super.setUp()
        storage = PersistentStorage(
            storagePrefix: "event-pipeline-tests",
            logger: nil,
            diagonostics: Diagnostics(),
            diagnosticsClient: FakeDiagnosticsClient())
        configuration = Configuration(
            apiKey: "testApiKey",
            flushIntervalMillis: Int(Self.FLUSH_INTERVAL_SECONDS * 1000),
            instanceName: UUID().uuidString,
            storageProvider: storage,
            offline: NetworkConnectivityCheckerPlugin.Disabled,
            httpClient: RemoteConfigMockServer()
        )
        let amplitude = Amplitude(configuration: configuration)
        httpClient = FakeHttpClient(configuration: configuration, diagnostics: configuration.diagonostics, serverZone: configuration.serverZone)
        pipeline = amplitude.plugins(type: AmplitudeDestinationPlugin.self)[0].pipeline!
        pipeline.httpClient = httpClient
        pipeline.stop()

    }

    override func tearDown() {
        super.tearDown()
        storage.reset()
    }

    func testRecoveryDoesNotRequirePersistentEventStorage() {
        let name = UUID().uuidString
        class StateStorage: InMemoryStorage, UploadRequestStateStorage {
            var uploadRequestPending = true
        }
        let stateStorage = StateStorage()
        let amplitude = Amplitude(configuration: Configuration(
            apiKey: "test", instanceName: name, storageProvider: stateStorage,
            identifyStorageProvider: InMemoryStorage(), autocapture: [],
            offline: NetworkConnectivityCheckerPlugin.Disabled, enableAutoCaptureRemoteConfig: false, httpClient: RemoteConfigMockServer()))
        let pipeline = EventPipeline(amplitude: amplitude)
        pipeline.stop()
        let firstScan = expectation(description: "recover previous request")
        pipeline.flush { firstScan.fulfill() }
        wait(for: [firstScan], timeout: 10)
        XCTAssertFalse(stateStorage.uploadRequestPending)

        stateStorage.uploadRequestPending = true
        let secondScan = expectation(description: "do not recover again")
        pipeline.flush { secondScan.fulfill() }
        wait(for: [secondScan], timeout: 10)
        XCTAssertTrue(stateStorage.uploadRequestPending)
    }

    func testDisabledDiagnosticsLeavesPendingMarkerUntouched() throws {
        configuration.enableDiagnostics = false
        storage.uploadRequestPending = true
        try storage.write(key: .EVENTS, value: BaseEvent(eventType: "accepted"))
        let scanned = expectation(description: "flush without updating the marker")
        pipeline.flush { scanned.fulfill() }
        wait(for: [scanned], timeout: 10)
        XCTAssertTrue(storage.uploadRequestPending)
    }

    func testPendingMarkerClearsOnSuccessAndErrorCallbacks() throws {
        class ObservingHttpClient: FakeHttpClient {
            var onRequest: (() -> Void)?
            override func upload(events: String, completion: @escaping (Result<Int, Error>) -> Void) -> (@Sendable () -> Void)? {
                onRequest?()
                return super.upload(events: events, completion: completion)
            }
        }
        for result: Result<Int, Error> in [.success(200), .failure(AnalyticsHttpClient.Exception.httpError(code: 500, data: nil))] {
            let completed = expectation(description: "response callback completed")
            let client = ObservingHttpClient(configuration: configuration, diagnostics: configuration.diagonostics, serverZone: configuration.serverZone)
            client.onRequest = { [storage] in
                XCTAssertTrue(storage?.uploadRequestPending == true)
            }
            client.uploadResults = [result]
            client.uploadExpectations = [completed]
            pipeline.httpClient = client
            configuration.flushMaxRetries = 0
            configuration.offline = false
            try storage.write(key: .EVENTS, value: BaseEvent(eventType: "test"))
            pipeline.flush()
            wait(for: [completed], timeout: 10)
            XCTAssertFalse(storage.uploadRequestPending)
        }
    }

    func testSuccessDeletesBatchBeforeClearingPendingMarker() throws {
        final class ObservingStorage: PersistentStorage {
            override func remove(eventBlock: EventBlock) {
                super.remove(eventBlock: eventBlock)
                XCTAssertTrue(uploadRequestPending, "Clear the marker after deleting the batch")
            }
        }
        let storage = ObservingStorage(storagePrefix: UUID().uuidString, logger: nil,
            diagonostics: Diagnostics(), diagnosticsClient: FakeDiagnosticsClient())
        let fixture = UploadFixture(storage: storage)
        defer { fixture.cleanUp() }
        try fixture.writeBatch(["accepted"])
        fixture.client.onUpload = { fixture.client.response?(.success(200)) }
        let flushed = expectation(description: "accepted batch handled")
        fixture.pipeline.flush { flushed.fulfill() }
        wait(for: [flushed], timeout: 10)
        XCTAssertTrue(try fixture.storedEventTypes().isEmpty)
        XCTAssertFalse(storage.uploadRequestPending)
    }

    func testCustomClientCancellationUsesNormalRetryPolicy() throws {
        actor CancellingClient {
            var firstRequest = true
            let requests: XCTestExpectation
            init(requests: XCTestExpectation) { self.requests = requests }
            func send(_ request: URLRequest) throws -> (Data, URLResponse) {
                requests.fulfill()
                if firstRequest {
                    firstRequest = false
                    throw URLError(.cancelled)
                }
                return (Data(), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            }
        }
        let requests = expectation(description: "custom cancellation is retried")
        requests.expectedFulfillmentCount = 2
        let client = CancellingClient(requests: requests)
        let transport = ClosureHttpClient { request in
            if request.httpMethod != "POST" { return try await RemoteConfigMockServer().send(request) }
            return try await client.send(request)
        }
        let storage = PersistentStorage(storagePrefix: UUID().uuidString, logger: nil,
            diagonostics: Diagnostics(), diagnosticsClient: FakeDiagnosticsClient())
        defer { storage.reset() }
        let config = Configuration(apiKey: "test", flushIntervalMillis: 3_600_000,
            instanceName: UUID().uuidString, storageProvider: storage, autocapture: [],
            offline: NetworkConnectivityCheckerPlugin.Disabled, enableAutoCaptureRemoteConfig: false,
            httpClient: transport)
        config.flushMaxRetries = 1
        let amplitude = Amplitude(configuration: config)
        let pipeline = EventPipeline(amplitude: amplitude)
        pipeline.stop()
        try storage.write(key: .EVENTS, value: BaseEvent(eventType: "custom-cancellation"))
        let flushed = expectation(description: "flush completes after retry")
        pipeline.flush { flushed.fulfill() }
        wait(for: [requests, flushed], timeout: 10)
        XCTAssertFalse(config.offline == true)
        XCTAssertFalse(storage.uploadRequestPending)
        let files: [URL] = try XCTUnwrap(storage.read(key: .EVENTS))
        XCTAssertTrue(files.isEmpty)
    }

    func testResponsesAndCallbacksCompleteWhileTrackingIsSuspended() throws {
        actor Responses {
            var firstStatus: Int?
            let requests: XCTestExpectation
            init(status: Int, requests: XCTestExpectation) {
                firstStatus = status
                self.requests = requests
            }
            func send(_ request: URLRequest) -> (Data, URLResponse) {
                let status = firstStatus ?? 200
                firstStatus = nil
                requests.fulfill()
                let body = status == 400 ? #"{"events_with_invalid_fields":{"event_type":[0]}}"# : "{}"
                return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
            }
        }
        for status in [200, 400, 413] {
            let requests = expectation(description: "all batches uploaded after \(status)")
            requests.expectedFulfillmentCount = status == 200 ? 1 : (status == 400 ? 2 : 3)
            let responses = Responses(status: status, requests: requests)
            let transport = ClosureHttpClient { request in
                if request.url?.absoluteString != Constants.DEFAULT_API_HOST {
                    return try await RemoteConfigMockServer().send(request)
                }
                return await responses.send(request)
            }
            let storage = PersistentStorage(storagePrefix: UUID().uuidString, logger: nil,
                diagonostics: Diagnostics(), diagnosticsClient: FakeDiagnosticsClient())
            defer { storage.reset() }
            let config = Configuration(apiKey: "test", flushQueueSize: 1, flushIntervalMillis: 3_600_000,
                instanceName: UUID().uuidString, storageProvider: storage, autocapture: [],
                offline: NetworkConnectivityCheckerPlugin.Disabled, enableAutoCaptureRemoteConfig: false,
                httpClient: transport)
            let amplitude = Amplitude(configuration: config)
            let pipeline = EventPipeline(amplitude: amplitude)
            pipeline.stop()
            let key = DispatchSpecificKey<Bool>()
            pipeline.httpClient.callbackQueue.setSpecific(key: key, value: true)
            let globalCallbacks = expectation(description: "global callbacks off upload queue")
            let eventCallbacks = expectation(description: "event callbacks off upload queue")
            globalCallbacks.expectedFulfillmentCount = 2
            eventCallbacks.expectedFulfillmentCount = 2
            var callbackCount = 0
            config.callback = { _, _, _ in
                XCTAssertNil(DispatchQueue.getSpecific(key: key))
                callbackCount += 1
                globalCallbacks.fulfill()
            }
            let ids = [UUID().uuidString, UUID().uuidString]
            for id in ids {
                let event = BaseEvent(eventType: "response-queue")
                event.insertId = id
                event.callback = { _, _, _ in
                    XCTAssertNil(DispatchQueue.getSpecific(key: key))
                    eventCallbacks.fulfill()
                }
                try storage.write(key: .EVENTS, value: event)
            }
            amplitude.trackingQueue.sync {}
            amplitude.trackingQueue.suspend()
            defer { amplitude.trackingQueue.resume() }
            let drained = expectation(description: "response processing completed without tracking")
            pipeline.flush {
                XCTAssertNil(DispatchQueue.getSpecific(key: key))
                XCTAssertEqual(callbackCount, 2)
                drained.fulfill()
            }
            wait(for: [requests, drained, globalCallbacks, eventCallbacks], timeout: 10)
            XCTAssertFalse(storage.uploadRequestPending)
            let files: [URL] = try XCTUnwrap(storage.read(key: .EVENTS))
            XCTAssertTrue(files.isEmpty)
            XCTAssertEqual(callbackCount, 2)
            for id in ids { XCTAssertNil(storage.getEventCallback(insertId: id)) }
        }
    }

    func testBlockedEventCallbackDoesNotBlockUploadsAndFlushCompletionRunsLast() throws {
        class ObservingClient: AnalyticsHttpClient {
            var onResponse: (() -> Void)?
            override func upload(events: String, completion: @escaping (Result<Int, Error>) -> Void) -> (@Sendable () -> Void)? {
                return super.upload(events: events) { result in
                    completion(result)
                    self.onResponse?()
                }
            }
        }
        let transport = ClosureHttpClient { request in
            if request.httpMethod != "POST" { return try await RemoteConfigMockServer().send(request) }
            return (Data(), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let storage = PersistentStorage(storagePrefix: UUID().uuidString, logger: nil,
            diagonostics: Diagnostics(), diagnosticsClient: FakeDiagnosticsClient())
        defer { storage.reset() }
        let config = Configuration(apiKey: "test", flushIntervalMillis: 3_600_000,
            instanceName: UUID().uuidString, storageProvider: storage, autocapture: [],
            offline: NetworkConnectivityCheckerPlugin.Disabled, enableAutoCaptureRemoteConfig: false,
            httpClient: transport)
        let amplitude = Amplitude(configuration: config)
        let pipeline = EventPipeline(amplitude: amplitude)
        pipeline.stop()
        let client = ObservingClient(configuration: config, diagnostics: config.diagonostics,
            callbackQueue: pipeline.httpClient.callbackQueue, serverZone: amplitude.amplitudeContext.serverZone)
        pipeline.httpClient = client
        let responses = expectation(description: "both responses processed while callback is blocked")
        responses.expectedFulfillmentCount = 2
        client.onResponse = { responses.fulfill() }
        let callbackStarted = expectation(description: "first callback started")
        let releaseCallback = DispatchSemaphore(value: 0)
        defer { releaseCallback.signal() }
        var order = [String]()
        config.callback = { event, _, _ in
            order.append("global-\(event.eventType)")
            if event.eventType == "first" {
                callbackStarted.fulfill()
                XCTAssertEqual(releaseCallback.wait(timeout: .now() + 10), .success)
            }
        }
        for name in ["first", "second"] {
            let event = BaseEvent(eventType: name)
            event.insertId = UUID().uuidString
            event.callback = { _, _, _ in order.append("event-\(name)") }
            try storage.write(key: .EVENTS, value: event)
            storage.rollover()
        }
        let drained = expectation(description: "flush completion follows event callbacks")
        pipeline.flush {
            XCTAssertEqual(order, ["global-first", "event-first", "global-second", "event-second"])
            drained.fulfill()
        }
        wait(for: [callbackStarted, responses], timeout: 10)
        XCTAssertFalse(storage.uploadRequestPending)
        let files: [URL] = try XCTUnwrap(storage.read(key: .EVENTS))
        XCTAssertTrue(files.isEmpty)
        releaseCallback.signal()
        wait(for: [drained], timeout: 10)
    }

    private final class ExpiringVendor: VendorSystem {
        var lifecycle = ApplicationLifecycle()
        override func makeApplicationLifecycle() -> ApplicationLifecycle { lifecycle }
        var isExtension = false
        override var isRunningInAppExtension: Bool { isExtension }
        var expireDuringStart = false
        var expire: (() -> Void)?
        var onEnd: (() -> Void)?
        var endCount = 0
        override func beginBackgroundTask(label: String? = nil, expirationHandler: @escaping () -> Void) -> BackgroundTaskCompletionCallback? {
            XCTAssertEqual(label, "amplitude.upload")
            expire = expirationHandler
            if expireDuringStart { expirationHandler() }
            return {
                self.endCount += 1
                self.onEnd?()
            }
        }
    }
    private final class ControlledClient: AnalyticsHttpClient {
        var onUpload: (() -> Void)?
        var response: ((Result<Int, Error>) -> Void)?
        var uploadCount = 0
        override func upload(events: String, completion: @escaping (Result<Int, Error>) -> Void) -> (@Sendable () -> Void)? {
            uploadCount += 1
            response = { result in self.callbackQueue.async { completion(result) } }
            onUpload?()
            return { XCTFail("Expiration must not cancel the request") }
        }
    }
    private final class UploadFixture {
        let storage: PersistentStorage
        let amplitude: Amplitude
        let vendor = ExpiringVendor()
        let pipeline: EventPipeline
        let client: ControlledClient

        init(storage: PersistentStorage? = nil, isExtension: Bool = false, suspendTimer: Bool = true,
             replaceDestination: Bool = false, monitor: ApplicationLifecycle? = nil,
             configure: ((Configuration) -> Void)? = nil) {
            self.storage = storage ?? PersistentStorage(storagePrefix: UUID().uuidString, logger: nil,
                diagonostics: Diagnostics(), diagnosticsClient: FakeDiagnosticsClient())
            let config = Configuration(apiKey: "test", flushQueueSize: 1, flushIntervalMillis: 3_600_000,
                instanceName: UUID().uuidString, storageProvider: self.storage, autocapture: [],
                offline: NetworkConnectivityCheckerPlugin.Disabled, enableAutoCaptureRemoteConfig: false,
                httpClient: RemoteConfigMockServer())
            config.flushMaxRetries = 0
            config.flushEventsOnClose = false
            configure?(config)
            vendor.isExtension = isExtension
            let previousVendor = VendorSystem.current
            vendor.lifecycle = monitor ?? previousVendor.makeApplicationLifecycle()
            VendorSystem.current = vendor
            defer { VendorSystem.current = previousVendor }
            amplitude = Amplitude(configuration: config)
            if replaceDestination {
                amplitude.remove(plugin: amplitude.plugins(type: AmplitudeDestinationPlugin.self)[0])
                amplitude.add(plugin: AmplitudeDestinationPlugin())
            }
            pipeline = amplitude.plugins(type: AmplitudeDestinationPlugin.self)[0].pipeline!
            client = ControlledClient(configuration: config, diagnostics: config.diagonostics,
                callbackQueue: pipeline.httpClient.callbackQueue, serverZone: config.serverZone)
            pipeline.httpClient = client
            if suspendTimer { pipeline.stop() }
        }

        func cleanUp() {
            pipeline.stop()
            client.callbackQueue.sync {}
            vendor.expire = nil
            vendor.onEnd = nil
            client.response = nil
            client.onUpload = nil
            storage.reset()
        }

        func writeBatch(_ eventTypes: [String]) throws {
            for eventType in eventTypes {
                try storage.write(key: .EVENTS, value: BaseEvent(eventType: eventType))
            }
            storage.rollover()
        }

        func storedEventTypes() throws -> [String] {
            let files: [URL] = try XCTUnwrap(storage.read(key: .EVENTS))
            return try files.flatMap { file in
                let json = try XCTUnwrap(storage.getEventsString(eventBlock: file))
                return try XCTUnwrap(BaseEvent.fromArrayString(jsonString: json)).map(\.eventType)
            }
        }
    }

    func testExpirationBlocksAllNewUploadsUntilForeground() throws {
        for expireFirst in [false, true] {
            let fixture = UploadFixture()
            defer { fixture.cleanUp() }
            try fixture.writeBatch(["first"])
            try fixture.writeBatch(["second"])
            let started = expectation(description: "first request started")
            let firstFlush = expectation(description: "first flush finished")
            let explicitFlush = expectation(description: "new explicit flush stops at the expired request")
            fixture.client.onUpload = { started.fulfill() }
            fixture.pipeline.flush { firstFlush.fulfill() }
            wait(for: [started], timeout: 10)

            fixture.amplitude.appLifecycle.enterBackground()
            if expireFirst { fixture.vendor.expire?() }
            fixture.pipeline.flush { explicitFlush.fulfill() }
            fixture.client.callbackQueue.sync {}
            if !expireFirst { fixture.vendor.expire?() }
            fixture.client.onUpload = { fixture.client.response?(.success(200)) }
            fixture.client.response?(.success(200))
            wait(for: [firstFlush, explicitFlush], timeout: 10)

            XCTAssertEqual(fixture.client.uploadCount, 1)
            XCTAssertEqual(fixture.vendor.endCount, 1)
            let remaining: [URL] = try XCTUnwrap(fixture.storage.read(key: .EVENTS))
            XCTAssertEqual(remaining.count, 1)

            fixture.pipeline.put(event: BaseEvent(eventType: "third"))
            let blocked = expectation(description: "explicit and event-count flushes remain blocked")
            fixture.pipeline.flush { blocked.fulfill() }
            wait(for: [blocked], timeout: 10)
            XCTAssertEqual(fixture.client.uploadCount, 1)

            fixture.amplitude.appLifecycle.enterForeground()
            let resumed = expectation(description: "foreground permits uploads again")
            fixture.pipeline.flush { resumed.fulfill() }
            wait(for: [resumed], timeout: 10)
            XCTAssertEqual(fixture.client.uploadCount, 3)
            let afterForeground: [URL] = try XCTUnwrap(fixture.storage.read(key: .EVENTS))
            XCTAssertTrue(afterForeground.isEmpty)
        }
    }

#if (os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)) && !AMPLITUDE_DISABLE_UIKIT
    func testFlushTimerFollowsLifecycleAndExpirationPolicy() throws {
        class ExpiringVendor: IOSVendorSystem {
            var shouldExpire = true
            var onExpire: (() -> Void)?
            override func beginBackgroundTask(label: String? = nil, expirationHandler: @escaping () -> Void) -> BackgroundTaskCompletionCallback? {
                if shouldExpire {
                    expirationHandler()
                    onExpire?()
                }
                return {}
            }
        }
        IOSVendorSystem.overrideApplicationState(.background)
        defer { IOSVendorSystem.overrideApplicationState(nil) }
        let storage = PersistentStorage(storagePrefix: UUID().uuidString, logger: nil,
            diagonostics: Diagnostics(), diagnosticsClient: FakeDiagnosticsClient())
        defer { storage.reset() }
        let config = Configuration(apiKey: "test", flushIntervalMillis: 3_600_000,
            instanceName: UUID().uuidString, storageProvider: storage, autocapture: [],
            offline: NetworkConnectivityCheckerPlugin.Disabled, enableAutoCaptureRemoteConfig: false,
            httpClient: RemoteConfigMockServer())
        config.flushEventsOnClose = false
        let amplitude = Amplitude(configuration: config)
        let lifecycle = amplitude.appLifecycle
        let vendor = ExpiringVendor()
        let pipeline = EventPipeline(amplitude: amplitude, vendorSystem: vendor)
        let uploadQueue = pipeline.httpClient.callbackQueue
        amplitude.waitForTrackingQueue()
        amplitude.trackingQueue.suspend()
        defer { amplitude.trackingQueue.resume() }
        XCTAssertEqual(pipeline.flushTimer?.isRunning, true, "Preserve timer startup for a background launch")

        lifecycle.enterBackground()
        uploadQueue.sync {}
#if targetEnvironment(macCatalyst)
        XCTAssertEqual(pipeline.flushTimer?.isRunning, true, "Catalyst keeps periodic flushing in the background")
#else
        XCTAssertEqual(pipeline.flushTimer?.isRunning, false, "Backgrounding stops periodic flushing")
#endif

        lifecycle.enterForeground()
        uploadQueue.sync {}
        XCTAssertEqual(pipeline.flushTimer?.isRunning, true)
        lifecycle.enterBackground()
        try storage.write(key: .EVENTS, value: BaseEvent(eventType: "expiring-upload"))
        let expired = expectation(description: "response processed after expiration")
        pipeline.flush { expired.fulfill() }
        wait(for: [expired], timeout: 10)
        uploadQueue.sync {}
        XCTAssertEqual(pipeline.flushTimer?.isRunning, false)

        vendor.shouldExpire = false
        try storage.write(key: .EVENTS, value: BaseEvent(eventType: "explicit-background-flush"))
        let flushed = expectation(description: "explicit flush is blocked after expiration")
        pipeline.flush { flushed.fulfill() }
        wait(for: [flushed], timeout: 10)
        let files: [URL] = try XCTUnwrap(storage.read(key: .EVENTS))
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(pipeline.flushTimer?.isRunning, false)

        for _ in 0..<2 {
            lifecycle.enterForeground()
        }
        uploadQueue.sync {}
        XCTAssertEqual(pipeline.flushTimer?.isRunning, true)
        lifecycle.enterBackground()
        let foregroundFlush = expectation(description: "flushes remain allowed after backgrounding without expiry")
        pipeline.flush { foregroundFlush.fulfill() }
        wait(for: [foregroundFlush], timeout: 10)
        let remaining: [URL] = try XCTUnwrap(storage.read(key: .EVENTS))
        XCTAssertTrue(remaining.isEmpty)

        // Backgrounding must preserve a suspension; only foregrounding resumes it.
        for shouldRun in [true, false] {
            let transition = {
                if shouldRun { lifecycle.enterForeground() } else { lifecycle.enterBackground() }
            }
            pipeline.stop()
            transition()
            uploadQueue.sync {}
            XCTAssertEqual(pipeline.flushTimer?.isRunning, shouldRun)

            vendor.shouldExpire = true
            vendor.onExpire = transition
            try storage.write(key: .EVENTS, value: BaseEvent(eventType: "lifecycle-transition-during-expiry"))
            let transitioned = expectation(description: "expiry and lifecycle transitions preserve timer policy")
            pipeline.flush { transitioned.fulfill() }
            wait(for: [transitioned], timeout: 10)
            uploadQueue.sync {}
            XCTAssertEqual(pipeline.flushTimer?.isRunning, shouldRun)
            vendor.onExpire = nil
        }
    }

    func testCloseFlushUploadsAutocapturedBackgroundEvent() throws {
        final class CloseFlushObserver: EventCollectorPlugin {
            override func flush() {
                XCTAssertEqual(events.map(\.eventType), [Constants.AMP_APPLICATION_BACKGROUNDED_EVENT])
            }
        }
        let delivered = expectation(description: "close flush acknowledged the background event")
        let fixture = UploadFixture(monitor: ApplicationLifecycle()) { config in
            config.autocapture = [.appLifecycles]
            config.flushQueueSize = 100
            config.flushEventsOnClose = true
            config.callback = { event, code, _ in
                XCTAssertEqual(event.eventType, Constants.AMP_APPLICATION_BACKGROUNDED_EVENT)
                XCTAssertEqual(code, 200)
                delivered.fulfill()
            }
        }
        defer { fixture.cleanUp() }
        fixture.amplitude.add(plugin: CloseFlushObserver())
        fixture.client.onUpload = { fixture.client.response?(.success(200)) }
        XCTAssertTrue(try fixture.storedEventTypes().isEmpty)

        fixture.amplitude.appLifecycle.enterBackground()

        wait(for: [delivered], timeout: 10)
        XCTAssertEqual(fixture.client.uploadCount, 1)
        XCTAssertTrue(try fixture.storedEventTypes().isEmpty)
    }

    func testTimerDistinguishesBackgroundLaunchFromBackgroundingDuringSetup() throws {
        for backgroundsDuringSetup in [false, true] {
            IOSVendorSystem.overrideApplicationState(backgroundsDuringSetup ? .active : .background)
            defer { IOSVendorSystem.overrideApplicationState(nil) }
            var postedDuringSetup = false
            let fixture = UploadFixture(suspendTimer: false) { config in
                config.flushQueueSize = 100
                config.flushIntervalMillis = 50
                if backgroundsDuringSetup {
                    // ContextPlugin setup follows lifecycle startup and precedes destination setup.
                    config.deviceId = "00000000-0000-0000-0000-000000000000"
                    config.loggerProvider = ObjCLoggerProviderWrapper(logLevel: .warn) { _, message in
                        guard message.hasPrefix("Configured deviceId") else { return }
                        postedDuringSetup = true
                        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
                    }
                }
            }
            defer { fixture.cleanUp() }
            XCTAssertEqual(postedDuringSetup, backgroundsDuringSetup)
#if targetEnvironment(macCatalyst)
            let shouldPause = false
#else
            let shouldPause = backgroundsDuringSetup
#endif
            fixture.client.callbackQueue.sync {}
            XCTAssertEqual(fixture.pipeline.flushTimer?.isRunning, !shouldPause)
            let uploaded = expectation(description: "below-threshold timer upload")
            uploaded.isInverted = shouldPause
            fixture.client.onUpload = {
                uploaded.fulfill()
                fixture.client.response?(.success(200))
            }
            fixture.amplitude.track(eventType: "below-threshold")
            fixture.amplitude.trackingQueue.sync {}
            wait(for: [uploaded], timeout: shouldPause ? 0.3 : 10)
            if shouldPause {
                XCTAssertEqual(fixture.client.uploadCount, 0)
                fixture.client.onUpload = { fixture.client.response?(.success(200)) }
            }
            let drained = expectation(description: "explicit flush acknowledges pending data")
            fixture.pipeline.flush { drained.fulfill() }
            wait(for: [drained], timeout: 10)
            XCTAssertEqual(fixture.client.uploadCount, 1)
            XCTAssertTrue(try fixture.storedEventTypes().isEmpty)
        }
    }

    func testPipelineReceivesAlreadyActiveStateAfterSDKInitialization() throws {
        IOSVendorSystem.overrideApplicationState(.active)
        defer { IOSVendorSystem.overrideApplicationState(nil) }
        for replaceDestination in [false, true] {
            let fixture = UploadFixture(suspendTimer: false, replaceDestination: replaceDestination)
            defer { fixture.cleanUp() }
            try fixture.writeBatch(["first"])
            let started = expectation(description: "already-active request started")
            let acknowledged = expectation(description: "expired request acknowledged")
            fixture.client.onUpload = { started.fulfill() }
            fixture.pipeline.flush { acknowledged.fulfill() }
            wait(for: [started], timeout: 10)
            fixture.vendor.expire?()
            fixture.client.response?(.success(200))
            wait(for: [acknowledged], timeout: 10)
            XCTAssertEqual(fixture.pipeline.flushTimer?.isRunning, true)

            try fixture.writeBatch(["second"])
            fixture.client.onUpload = { fixture.client.response?(.success(200)) }
            let drained = expectation(description: "explicit flush works without a foreground transition")
            fixture.pipeline.flush { drained.fulfill() }
            wait(for: [drained], timeout: 10)
            XCTAssertEqual(fixture.client.uploadCount, 2)
            XCTAssertEqual(fixture.vendor.endCount, 2)
            XCTAssertTrue(try fixture.storedEventTypes().isEmpty)
        }
    }

#if !targetEnvironment(macCatalyst)
    func testShortForegroundVisitsDeliverOverduePeriodicUpload() throws {
        IOSVendorSystem.overrideApplicationState(.background)
        defer { IOSVendorSystem.overrideApplicationState(nil) }
        let fixture = UploadFixture { config in
            config.flushQueueSize = 100
            config.flushIntervalMillis = 400
        }
        defer { fixture.cleanUp() }
        let uploaded = expectation(description: "short visits deliver a below-threshold event")
        fixture.client.onUpload = {
            uploaded.fulfill()
            fixture.client.response?(.success(200))
        }
        fixture.amplitude.track(eventType: "short-visit")
        fixture.amplitude.trackingQueue.sync {}
        let queue = fixture.client.callbackQueue
        fixture.amplitude.appLifecycle.enterBackground()
        queue.sync {}
        Thread.sleep(forTimeInterval: 0.5) // The first 400 ms deadline passes in the background.
        XCTAssertEqual(queue.sync { fixture.client.uploadCount }, 0)

        for _ in 0..<3 {
            fixture.amplitude.appLifecycle.enterForeground()
            queue.sync {}
            Thread.sleep(forTimeInterval: 0.08)
            fixture.amplitude.appLifecycle.enterBackground()
            queue.sync {}
        }
        wait(for: [uploaded], timeout: 1)
        queue.sync {}
        XCTAssertEqual(fixture.client.uploadCount, 1)
        XCTAssertTrue(try fixture.storedEventTypes().isEmpty)
    }
#endif

    func testForegroundBeforeExpirationDoesNotBlockUploads() throws {
        for expiresBeforeForeground in [false, true] {
            for succeeds in [false, true] {
                IOSVendorSystem.overrideApplicationState(.background)
                defer { IOSVendorSystem.overrideApplicationState(nil) }
                let fixture = UploadFixture()
                defer { fixture.cleanUp() }
                fixture.pipeline.configuration.flushMaxRetries = 1
                try fixture.writeBatch(["first"])
                try fixture.writeBatch(["second"])
                let started = expectation(description: "background request started")
                let drained = expectation(description: "foreground chain drains despite expiration")
                fixture.client.onUpload = { started.fulfill() }
                fixture.pipeline.flush { drained.fulfill() }
                wait(for: [started], timeout: 10)

                fixture.amplitude.trackingQueue.sync {}
                fixture.amplitude.trackingQueue.suspend()
                defer { fixture.amplitude.trackingQueue.resume() }
                if expiresBeforeForeground { fixture.vendor.expire?() }
                NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
                if !expiresBeforeForeground { fixture.vendor.expire?() }
                NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
                fixture.client.onUpload = { fixture.client.response?(.success(200)) }
                fixture.client.response?(succeeds ? .success(200) : .failure(URLError(.timedOut)))
                wait(for: [drained], timeout: 10)
                XCTAssertEqual(fixture.client.uploadCount, succeeds ? 2 : 3)
                XCTAssertEqual(fixture.vendor.endCount, fixture.client.uploadCount)
                XCTAssertEqual(fixture.pipeline.flushTimer?.isRunning, true)
                XCTAssertFalse(fixture.pipeline.configuration.offline == true)
                XCTAssertFalse(fixture.storage.uploadRequestPending)

                try fixture.writeBatch(["third"])
                let flushed = expectation(description: "explicit flush needs no further foreground transition")
                fixture.pipeline.flush { flushed.fulfill() }
                wait(for: [flushed], timeout: 10)
                XCTAssertEqual(fixture.client.uploadCount, succeeds ? 3 : 4)
                XCTAssertTrue(try fixture.storedEventTypes().isEmpty)
            }
        }
    }
#endif

    func testForegroundExpirationsPreserveRetryLimitAndBackoff() throws {
        for maxRetries in [0, 2] {
            let fixture = UploadFixture()
            defer { fixture.cleanUp() }
            fixture.pipeline.configuration.flushMaxRetries = maxRetries
            fixture.amplitude.appLifecycle.enterForeground()
            try fixture.writeBatch(["retry"])
            let stopped = expectation(description: "retry limit reached despite repeated expiration")
            var uploadTimes: [TimeInterval] = [] // Accessed on uploadsQueue until stopped.
            fixture.client.onUpload = {
                uploadTimes.append(ProcessInfo.processInfo.systemUptime)
                fixture.vendor.expire?()
                let result: Result<Int, Error> = fixture.client.uploadCount <= maxRetries + 1
                    ? .failure(AnalyticsHttpClient.Exception.httpError(code: 500, data: nil)) : .success(200)
                fixture.client.response?(result) // Bound a broken implementation rather than retry forever.
                if fixture.client.uploadCount == maxRetries + 1 {
                    fixture.client.callbackQueue.async {
                        // The response queues its continuation; inspect after that decision.
                        fixture.client.callbackQueue.async { stopped.fulfill() }
                    }
                }
            }
            fixture.pipeline.flush()
            wait(for: [stopped], timeout: 15)
            fixture.client.callbackQueue.sync {}
            XCTAssertEqual(fixture.client.uploadCount, maxRetries + 1)
            XCTAssertEqual(fixture.vendor.endCount, maxRetries + 1)
            XCTAssertEqual(fixture.pipeline.configuration.offline, true)
            XCTAssertEqual(fixture.pipeline.flushTimer?.isRunning, true)
            XCTAssertEqual(try fixture.storedEventTypes(), ["retry"])
            for index in 1..<uploadTimes.count {
                XCTAssertGreaterThanOrEqual(uploadTimes[index] - uploadTimes[index - 1], pow(2, Double(index - 1)) - 0.05)
            }
        }
    }

    func testPipelineReceivesTransitionsDuringLifecycleStartup() throws {
        final class StartupMonitor: ApplicationLifecycle {
            var initiallyInForeground = true
            override func start() -> Bool {
                guard super.start() else { return false }
                if initiallyInForeground {
                    enterForeground()
                    enterBackground()
                } else {
                    enterBackground()
                    enterForeground()
                }
                return true
            }
        }
        for initiallyInForeground in [false, true] {
            let monitor = StartupMonitor()
            monitor.initiallyInForeground = initiallyInForeground
            let fixture = UploadFixture(suspendTimer: false, monitor: monitor)
            defer { fixture.cleanUp() }
            try fixture.writeBatch(["first"])
            let started = expectation(description: "request started after lifecycle startup")
            let finished = expectation(description: "expired response processed")
            fixture.client.onUpload = { started.fulfill() }
            fixture.pipeline.flush { finished.fulfill() }
            wait(for: [started], timeout: 10)
            fixture.vendor.expire?()
            fixture.client.response?(.success(200))
            wait(for: [finished], timeout: 10)
            let shouldBlock = initiallyInForeground // The transition switched to the opposite state.
            XCTAssertEqual(fixture.pipeline.flushTimer?.isRunning, !shouldBlock)

            try fixture.writeBatch(["second"])
            fixture.client.onUpload = { fixture.client.response?(.success(200)) }
            let flushed = expectation(description: "flush uses the last startup transition")
            fixture.pipeline.flush { flushed.fulfill() }
            wait(for: [flushed], timeout: 10)
            XCTAssertEqual(fixture.client.uploadCount, shouldBlock ? 1 : 2)
            XCTAssertEqual(try fixture.storedEventTypes(), shouldBlock ? ["second"] : [])
        }
    }

    func testDuplicatePipelineRegistrationDoesNotDuplicateStateDelivery() {
        final class RecordingPipeline: EventPipeline {
            var states: [Bool] = []
            override func applicationWillEnterForeground(timestamp: Int64, fromBackground: Bool) {
                states.append(true)
                super.applicationWillEnterForeground(timestamp: timestamp, fromBackground: fromBackground)
            }
            override func applicationDidEnterBackground(timestamp: Int64) {
                states.append(false)
                super.applicationDidEnterBackground(timestamp: timestamp)
            }
        }
        let fixture = UploadFixture()
        defer { fixture.cleanUp() }
        let pipeline = RecordingPipeline(amplitude: fixture.amplitude)
        fixture.amplitude.appLifecycle.addObserver(pipeline)
        fixture.amplitude.appLifecycle.enterBackground()
        fixture.amplitude.appLifecycle.enterForeground()
        pipeline.httpClient.callbackQueue.sync {}
        XCTAssertEqual(pipeline.states, [false, true])
    }

    func testBackgroundAfterForegroundStillBlocksExpiredUploads() throws {
        for succeeds in [false, true] {
            let fixture = UploadFixture()
            defer { fixture.cleanUp() }
            try fixture.writeBatch(["first"])
            try fixture.writeBatch(["second"])
            let started = expectation(description: "request started")
            let stopped = expectation(description: "second background period expires")
            fixture.client.onUpload = { started.fulfill() }
            fixture.pipeline.flush { stopped.fulfill() }
            wait(for: [started], timeout: 10)

            fixture.amplitude.appLifecycle.enterForeground()
            fixture.amplitude.appLifecycle.enterBackground()
            fixture.vendor.expire?()
            fixture.client.onUpload = { fixture.client.response?(.success(200)) }
            fixture.client.response?(succeeds ? .success(200) : .failure(URLError(.timedOut)))
            wait(for: [stopped], timeout: 10)
            XCTAssertEqual(fixture.client.uploadCount, 1)
            XCTAssertEqual(fixture.pipeline.flushTimer?.isRunning, false)
            XCTAssertFalse(fixture.pipeline.configuration.offline == true)
            XCTAssertEqual(try fixture.storedEventTypes().sorted(), succeeds ? ["second"] : ["first", "second"])

            let blocked = expectation(description: "explicit flush remains blocked")
            fixture.pipeline.flush { blocked.fulfill() }
            wait(for: [blocked], timeout: 10)
            XCTAssertEqual(fixture.client.uploadCount, 1)
            fixture.amplitude.appLifecycle.enterForeground()
            let resumed = expectation(description: "another foreground transition recovers")
            fixture.pipeline.flush { resumed.fulfill() }
            wait(for: [resumed], timeout: 10)
            XCTAssertEqual(fixture.client.uploadCount, succeeds ? 2 : 3)
            XCTAssertTrue(try fixture.storedEventTypes().isEmpty)
        }
    }

    func testExtensionPreservesFlushRequestedAfterExpirationBeforeResponse() throws {
        let partialError = Data(#"{"events_with_invalid_fields":{"event_type":[0]}}"#.utf8)
        struct ResponseCase {
            let name: String
            let response: Result<Int, Error>
            let retained: [String]
            let resumedUploads: Int
        }
        let cases = [
            ResponseCase(name: "success", response: .success(200), retained: [], resumedUploads: 2),
            ResponseCase(name: "timeout", response: .failure(URLError(.timedOut)), retained: ["first", "retry"], resumedUploads: 3),
            ResponseCase(name: "partial", response: .failure(AnalyticsHttpClient.Exception.httpError(code: 400, data: partialError)),
                         retained: ["retry"], resumedUploads: 3),
            ResponseCase(name: "split", response: .failure(AnalyticsHttpClient.Exception.httpError(code: 413, data: nil)),
                         retained: ["first", "retry"], resumedUploads: 4),
        ]
        for testCase in cases {
            for afterExpiration in [false, true] {
                let fixture = UploadFixture(isExtension: true)
                defer { fixture.cleanUp() }
                try fixture.writeBatch(["first", "retry"])
                let started = expectation(description: "first request started")
                let restarted = afterExpiration ? expectation(description: "fresh chain started") : nil
                let firstFlush = expectation(description: "first flush completed")
                let freshFlush = expectation(description: "fresh flush completed")
                var completedFlushes = 0 // Only read and written on the callback queue until expectations finish.
                fixture.client.onUpload = { started.fulfill() }
                fixture.pipeline.flush {
                    completedFlushes += 1
                    firstFlush.fulfill()
                }
                wait(for: [started], timeout: 10)

                if afterExpiration { fixture.vendor.expire?() }
                fixture.client.callbackQueue.sync {}
                try fixture.writeBatch(["fresh"])
                fixture.pipeline.flush {
                    completedFlushes += 1
                    freshFlush.fulfill()
                }
                fixture.client.callbackQueue.sync {}
                if !afterExpiration { fixture.vendor.expire?() }
                fixture.client.onUpload = {
                    if afterExpiration && fixture.client.uploadCount == 2 {
                        restarted?.fulfill()
                    } else {
                        fixture.client.response?(.success(200))
                    }
                }
                fixture.client.response?(testCase.response)
                if afterExpiration {
                    wait(for: [try XCTUnwrap(restarted)], timeout: 10)
                    let callbacksChecked = expectation(description: "fresh flush waits for its response")
                    fixture.pipeline.dispatchCallbacks {
                        XCTAssertEqual(completedFlushes, 0)
                        callbacksChecked.fulfill()
                    }
                    wait(for: [callbacksChecked], timeout: 10)
                    fixture.client.response?(.success(200))
                }
                wait(for: [firstFlush, freshFlush], timeout: 10)

                XCTAssertEqual(completedFlushes, 2)
                XCTAssertEqual(fixture.client.uploadCount, afterExpiration ? testCase.resumedUploads : 1, testCase.name)
                XCTAssertEqual(fixture.vendor.endCount, fixture.client.uploadCount)
                XCTAssertFalse(fixture.pipeline.configuration.offline == true)
                XCTAssertFalse(fixture.storage.uploadRequestPending)
                let expectedEvents = afterExpiration ? [] : (testCase.retained + ["fresh"]).sorted()
                XCTAssertEqual(try fixture.storedEventTypes().sorted(), expectedEvents, testCase.name)
            }
        }
    }

    func testExtensionPendingFlushDoesNotSurviveAnotherExpiration() throws {
        let fixture = UploadFixture(isExtension: true)
        defer { fixture.cleanUp() }
        for event in ["first", "second", "third"] { try fixture.writeBatch([event]) }
        let firstStarted = expectation(description: "first request started")
        let secondStarted = expectation(description: "fresh chain started")
        let completions = expectation(description: "coalesced flushes complete once in order")
        completions.expectedFulfillmentCount = 4
        var completionOrder: [Int] = []
        fixture.client.onUpload = { firstStarted.fulfill() }
        fixture.pipeline.flush {
            completionOrder.append(0)
            completions.fulfill()
        }
        wait(for: [firstStarted], timeout: 10)
        fixture.vendor.expire?()
        for index in 1...3 {
            fixture.pipeline.flush {
                completionOrder.append(index)
                completions.fulfill()
            }
        }
        fixture.client.callbackQueue.sync {}
        fixture.vendor.expire?() // Repeated expiration must preserve the fresh flush waiting behind this request.
        fixture.client.onUpload = { secondStarted.fulfill() }
        fixture.client.response?(.success(200))
        wait(for: [secondStarted], timeout: 10)

        fixture.vendor.expire?()
        fixture.vendor.expire?()
        fixture.client.onUpload = { fixture.client.response?(.success(200)) }
        fixture.client.response?(.success(200))
        wait(for: [completions], timeout: 10)
        XCTAssertEqual(completionOrder, [0, 1, 2, 3])
        XCTAssertEqual(fixture.client.uploadCount, 2, "The earlier pending flush cannot restart a second expired chain")
        XCTAssertEqual(fixture.vendor.endCount, 2)
        XCTAssertEqual(try fixture.storedEventTypes(), ["third"])

        let drained = expectation(description: "new explicit flush still works")
        fixture.pipeline.flush { drained.fulfill() }
        wait(for: [drained], timeout: 10)
        XCTAssertEqual(fixture.client.uploadCount, 3)
        XCTAssertTrue(try fixture.storedEventTypes().isEmpty)
    }

    func testExtensionFreshEventCountFlushRestartsButTimerTickDoesNot() throws {
        for eventCountFlush in [false, true] {
            let fixture = UploadFixture(isExtension: true, suspendTimer: false)
            defer { fixture.cleanUp() }
            try fixture.writeBatch(["first"])
            let started = expectation(description: "first request started")
            let finished = expectation(description: "expired response processed")
            fixture.client.onUpload = { started.fulfill() }
            fixture.pipeline.flush { finished.fulfill() }
            wait(for: [started], timeout: 10)
            fixture.vendor.expire?()
            fixture.client.callbackQueue.sync {}
            if eventCountFlush {
                fixture.pipeline.put(event: BaseEvent(eventType: "fresh"))
            } else {
                try fixture.writeBatch(["fresh"])
                fixture.client.callbackQueue.sync { fixture.pipeline.flushOnTimer() }
            }
            fixture.client.callbackQueue.sync {}
            fixture.client.onUpload = { fixture.client.response?(.success(200)) }
            fixture.client.response?(.success(200))
            wait(for: [finished], timeout: 10)
            XCTAssertEqual(fixture.client.uploadCount, eventCountFlush ? 2 : 1)
            XCTAssertEqual(try fixture.storedEventTypes(), eventCountFlush ? [] : ["fresh"])
            XCTAssertEqual(fixture.pipeline.flushTimer?.isRunning, true)
        }
    }

    func testTimerTickBetweenExtensionEventsPreservesThresholdAfterExpiration() throws {
        let fixture = UploadFixture(isExtension: true) { $0.flushQueueSize = 2 }
        defer { fixture.cleanUp() }
        try fixture.writeBatch(["original"])
        let started = expectation(description: "original request started")
        let drained = expectation(description: "fresh threshold batch acknowledged")
        fixture.client.onUpload = { started.fulfill() }
        fixture.pipeline.flush { drained.fulfill() }
        wait(for: [started], timeout: 10)
        fixture.vendor.expire?()
        fixture.client.callbackQueue.sync {}

        fixture.pipeline.put(event: BaseEvent(eventType: "first"))
        fixture.client.callbackQueue.sync { fixture.pipeline.flushOnTimer() }
        fixture.pipeline.put(event: BaseEvent(eventType: "second"))
        fixture.client.callbackQueue.sync {}
        XCTAssertEqual(fixture.client.uploadCount, 1)

        fixture.client.onUpload = { fixture.client.response?(.success(200)) }
        fixture.client.response?(.success(200))
        wait(for: [drained], timeout: 10)
        XCTAssertEqual(fixture.client.uploadCount, 2)
        XCTAssertTrue(try fixture.storedEventTypes().isEmpty)
    }

    func testExtensionThresholdFlushSurvivesConcurrentCountReset() throws {
        final class InterleavedPipeline: EventPipeline {
            var beforeCountRead: (() -> Void)?
            override var eventCount: Int {
                get {
                    let tick = beforeCountRead
                    beforeCountRead = nil
                    tick?()
                    return super.eventCount
                }
                set { super.eventCount = newValue }
            }
        }
        let fixture = UploadFixture(isExtension: true)
        defer { fixture.cleanUp() }
        let pipeline = InterleavedPipeline(amplitude: fixture.amplitude, vendorSystem: fixture.vendor)
        let client = ControlledClient(configuration: pipeline.configuration, diagnostics: pipeline.configuration.diagonostics,
                                      callbackQueue: pipeline.httpClient.callbackQueue, serverZone: fixture.amplitude.amplitudeContext.serverZone)
        pipeline.httpClient = client
        defer { client.response = nil; client.onUpload = nil }
        try fixture.writeBatch(["first"])
        let started = expectation(description: "first upload started")
        let finished = expectation(description: "expired chain and pending flush finished")
        client.onUpload = { started.fulfill() }
        pipeline.flush { finished.fulfill() }
        wait(for: [started], timeout: 10)
        fixture.vendor.expire?()
        client.callbackQueue.sync {}

        // Reset the shared count on the upload queue at its first read after the increment.
        let reset = expectation(description: "concurrent reset after increment")
        pipeline.beforeCountRead = {
            client.callbackQueue.sync { pipeline.eventCount = 0 }
            reset.fulfill()
        }
        pipeline.put(event: BaseEvent(eventType: "fresh"))
        wait(for: [reset], timeout: 10)
        client.onUpload = { client.response?(.success(200)) }
        client.response?(.success(200))
        wait(for: [finished], timeout: 10)
        XCTAssertEqual(client.uploadCount, 2)
        XCTAssertTrue(try fixture.storedEventTypes().isEmpty)
    }

    func testStaleExpirationDoesNotAffectAnotherRequest() throws {
        for isExtension in [false, true] {
            let fixture = UploadFixture(isExtension: isExtension, suspendTimer: false)
            defer { fixture.cleanUp() }
            try fixture.writeBatch(["first"])
            try fixture.writeBatch(["second"])
            let firstStarted = expectation(description: "first request started")
            let secondStarted = expectation(description: "second request started")
            let drained = expectation(description: "stale expiration cannot stop the current chain")
            fixture.client.onUpload = { firstStarted.fulfill() }
            fixture.pipeline.flush { drained.fulfill() }
            wait(for: [firstStarted], timeout: 10)
            let oldExpiration = try XCTUnwrap(fixture.vendor.expire)
            fixture.client.onUpload = { secondStarted.fulfill() }
            fixture.client.response?(.success(200))
            wait(for: [secondStarted], timeout: 10)

            try fixture.writeBatch(["third"])
            oldExpiration()
            oldExpiration()
            fixture.client.callbackQueue.sync {}
            XCTAssertEqual(fixture.vendor.endCount, 1)
            XCTAssertEqual(fixture.pipeline.flushTimer?.isRunning, true)
            fixture.client.onUpload = { fixture.client.response?(.success(200)) }
            fixture.client.response?(.success(200))
            wait(for: [drained], timeout: 10)
            XCTAssertEqual(fixture.client.uploadCount, 3)
            XCTAssertEqual(fixture.vendor.endCount, 3)
            XCTAssertTrue(try fixture.storedEventTypes().isEmpty)
        }
    }

    func testExtensionExpirationStopsOnlyCurrentChain() throws {
        for succeeds in [false, true] {
            for automatic in [false, true] {
                let fixture = UploadFixture(isExtension: true, suspendTimer: false)
                defer { fixture.cleanUp() }
                fixture.client.callbackQueue.sync {}
                XCTAssertEqual(fixture.pipeline.flushTimer?.isRunning, true)

                try fixture.writeBatch(["first"])
                try fixture.writeBatch(["second"])
                let started = expectation(description: "extension request started")
                let ended = expectation(description: "expired activity ended before response")
                let stopped = expectation(description: "expired extension chain stopped")
                fixture.client.onUpload = { started.fulfill() }
                fixture.vendor.onEnd = { ended.fulfill() }
                fixture.pipeline.flush { stopped.fulfill() }
                wait(for: [started], timeout: 10)
                fixture.vendor.expire?()
                wait(for: [ended], timeout: 10)
                fixture.vendor.onEnd = nil
                fixture.client.response?(succeeds ? .success(200) : .failure(URLError(.timedOut)))
                wait(for: [stopped], timeout: 10)
                fixture.client.callbackQueue.sync {}

                XCTAssertEqual(fixture.client.uploadCount, 1)
                XCTAssertEqual(fixture.vendor.endCount, 1)
                XCTAssertFalse(fixture.pipeline.configuration.offline == true)
                XCTAssertEqual(fixture.pipeline.flushTimer?.isRunning, true)
                let remaining: [URL] = try XCTUnwrap(fixture.storage.read(key: .EVENTS))
                XCTAssertEqual(remaining.count, succeeds ? 1 : 2)

                let drained = expectation(description: "later extension flush starts a fresh chain")
                fixture.client.onUpload = { fixture.client.response?(.success(200)) }
                if automatic {
                    drained.expectedFulfillmentCount = remaining.count
                    fixture.vendor.onEnd = { drained.fulfill() }
                    fixture.client.callbackQueue.sync { fixture.pipeline.flushOnTimer() }
                } else {
                    fixture.pipeline.flush { drained.fulfill() }
                }
                wait(for: [drained], timeout: 10)
                XCTAssertEqual(fixture.client.uploadCount, succeeds ? 2 : 3)
                XCTAssertEqual(fixture.vendor.endCount, fixture.client.uploadCount)
                let afterFlush: [URL] = try XCTUnwrap(fixture.storage.read(key: .EVENTS))
                XCTAssertTrue(afterFlush.isEmpty)
            }
        }
    }

    func testAutomaticFlushDoesNotRestartExpiredRequest() throws {
        let fixture = UploadFixture(suspendTimer: false)
        defer { fixture.cleanUp() }
        try fixture.writeBatch(["first"])
        try fixture.writeBatch(["second"])
        let started = expectation(description: "request started")
        let stopped = expectation(description: "expired flush stopped")
        fixture.client.onUpload = { started.fulfill() }
        fixture.pipeline.flush { stopped.fulfill() }
        wait(for: [started], timeout: 10)
        fixture.client.callbackQueue.sync { fixture.pipeline.flushOnTimer() }
        fixture.client.callbackQueue.sync {}
        fixture.amplitude.appLifecycle.enterBackground()
        fixture.vendor.expire?()
        fixture.client.response?(.success(200))
        wait(for: [stopped], timeout: 10)

        XCTAssertEqual(fixture.client.uploadCount, 1)
        let remaining: [URL] = try XCTUnwrap(fixture.storage.read(key: .EVENTS))
        XCTAssertEqual(remaining.count, 1)
    }

    func testExpiredPartialFailureDoesNotStartRetryFlush() throws {
        for isExtension in [false, true] {
            for threshold in [1, 2] {
                let fixture = UploadFixture(isExtension: isExtension)
                defer { fixture.cleanUp() }
                fixture.pipeline.configuration.flushQueueSize = threshold
                try fixture.writeBatch(["invalid", "retry-a", "retry-b"])
                let started = expectation(description: "request started")
                let stopped = expectation(description: "expired partial failure processed")
                fixture.client.onUpload = { started.fulfill() }
                fixture.pipeline.flush { stopped.fulfill() }
                wait(for: [started], timeout: 10)
                if !isExtension { fixture.amplitude.appLifecycle.enterBackground() }
                fixture.vendor.expire?()
                let data = Data(#"{"events_with_invalid_fields":{"event_type":[0]}}"#.utf8)
                fixture.client.response?(.failure(AnalyticsHttpClient.Exception.httpError(code: 400, data: data)))
                wait(for: [stopped], timeout: 10)
                fixture.client.callbackQueue.sync {}

                XCTAssertEqual(fixture.client.uploadCount, 1, "Response retries must not start a fresh flush after expiry")
                XCTAssertEqual(try fixture.storedEventTypes().sorted(), ["retry-a", "retry-b"])
                XCTAssertFalse(fixture.pipeline.configuration.offline == true)

                if !isExtension { fixture.amplitude.appLifecycle.enterForeground() }
                let drained = expectation(description: "later permitted flush uploads the retry")
                fixture.client.onUpload = { fixture.client.response?(.success(200)) }
                fixture.pipeline.flush { drained.fulfill() }
                wait(for: [drained], timeout: 10)
                XCTAssertEqual(fixture.client.uploadCount, 1 + 2 / threshold)
                XCTAssertTrue(try fixture.storedEventTypes().isEmpty)
            }
        }
    }

    func testPartialFailureRetriesContinueWithoutExpiration() throws {
        for threshold in [1, 2] {
            let fixture = UploadFixture()
            defer { fixture.cleanUp() }
            fixture.pipeline.configuration.flushQueueSize = threshold
            var callbacks: [String] = []
            fixture.pipeline.configuration.callback = { event, code, _ in
                callbacks.append("\(event.eventType):\(code)")
            }
            try fixture.writeBatch(["invalid", "retry-a", "retry-b"])
            let data = Data(#"{"events_with_invalid_fields":{"event_type":[0]}}"#.utf8)
            fixture.client.onUpload = {
                fixture.client.response?(fixture.client.uploadCount == 1
                    ? .failure(AnalyticsHttpClient.Exception.httpError(code: 400, data: data)) : .success(200))
            }
            let drained = expectation(description: "existing chain handles retry batches without another flush")
            fixture.pipeline.flush { drained.fulfill() }
            wait(for: [drained], timeout: 10)
            XCTAssertEqual(fixture.client.uploadCount, 1 + 2 / threshold)
            XCTAssertEqual(callbacks.sorted(), ["invalid:400", "retry-a:200", "retry-b:200"])
            XCTAssertTrue(try fixture.storedEventTypes().isEmpty)
        }
    }

    func testExpirationDuringResponseProcessingStopsContinuation() throws {
        class ExpiringStorage: PersistentStorage {
            var onResponse: (() -> Void)?
            override func getResponseHandler(configuration: Configuration, eventPipeline: EventPipeline,
                                             eventBlock: URL, eventsString: String) -> ResponseHandler {
                onResponse?()
                return super.getResponseHandler(configuration: configuration, eventPipeline: eventPipeline,
                    eventBlock: eventBlock, eventsString: eventsString)
            }
        }
        for succeeds in [false, true] {
            let storage = ExpiringStorage(storagePrefix: UUID().uuidString, logger: nil,
                diagonostics: Diagnostics(), diagnosticsClient: FakeDiagnosticsClient())
            let fixture = UploadFixture(storage: storage, suspendTimer: false)
            defer {
                storage.onResponse = nil
                fixture.cleanUp()
            }
            try fixture.writeBatch(["first"])
            try fixture.writeBatch(["second"])
            let started = expectation(description: "request started")
            let stopped = expectation(description: "expiry during response prevented continuation")
            fixture.client.onUpload = { started.fulfill() }
            fixture.pipeline.flush { stopped.fulfill() }
            wait(for: [started], timeout: 10)
            fixture.amplitude.appLifecycle.enterBackground()
            storage.onResponse = { fixture.vendor.expire?() }
            fixture.client.response?(succeeds ? .success(200) : .failure(URLError(.timedOut)))
            wait(for: [stopped], timeout: 10)
            fixture.client.callbackQueue.sync {}

            XCTAssertEqual(fixture.client.uploadCount, 1)
            XCTAssertEqual(fixture.vendor.endCount, 1)
            XCTAssertFalse(fixture.pipeline.configuration.offline == true)
            XCTAssertEqual(fixture.pipeline.flushTimer?.isRunning, false)
            let remaining: [URL] = try XCTUnwrap(storage.read(key: .EVENTS))
            XCTAssertEqual(remaining.count, succeeds ? 1 : 2)

            fixture.amplitude.appLifecycle.enterForeground()
            fixture.client.callbackQueue.sync {}
            fixture.vendor.expire?() // A stale callback after continuation was decided is harmless.
            fixture.client.callbackQueue.sync {}
            XCTAssertEqual(fixture.pipeline.flushTimer?.isRunning, true)
            XCTAssertEqual(fixture.vendor.endCount, 1)
        }
    }

    func testExpirationEndsTaskWithoutCancellingAndStopsAfterResponse() throws {
        for expireDuringStart in [false, true] {
            for succeeds in [false, true] {
                let fixture = UploadFixture()
                defer { fixture.cleanUp() }
                let vendor = fixture.vendor
                let client = fixture.client
                let storage = fixture.storage
                vendor.expireDuringStart = expireDuringStart
                try fixture.writeBatch(["first"])
                try fixture.writeBatch(["second"])
                let files: [URL] = try XCTUnwrap(storage.read(key: .EVENTS))
                XCTAssertEqual(files.count, 2)
                let started = expectation(description: "upload started")
                let ended = expectation(description: "assertion ended without waiting for a response")
                let stopped = expectation(description: "expired chain stopped after handling its response")
                client.onUpload = { started.fulfill() }
                vendor.onEnd = { ended.fulfill() }
                fixture.amplitude.trackingQueue.sync {}
                fixture.amplitude.trackingQueue.suspend()
                defer { fixture.amplitude.trackingQueue.resume() }
                fixture.amplitude.appLifecycle.enterBackground()
                fixture.pipeline.flush { stopped.fulfill() }
                wait(for: [started], timeout: 10)
                if !expireDuringStart { vendor.expire?() }
                wait(for: [ended], timeout: 10)
                XCTAssertTrue(storage.uploadRequestPending)
                XCTAssertTrue(files.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
                vendor.onEnd = nil
                client.response?(succeeds ? .success(200) : .failure(URLError(.timedOut)))
                wait(for: [stopped], timeout: 10)
                XCTAssertEqual(client.uploadCount, 1)
                XCTAssertEqual(vendor.endCount, 1, "The late response must not end the assertion again")
                XCTAssertFalse(fixture.amplitude.configuration.offline == true)
                XCTAssertFalse(storage.uploadRequestPending)
                XCTAssertEqual(FileManager.default.fileExists(atPath: files[0].path), !succeeds)
                XCTAssertTrue(FileManager.default.fileExists(atPath: files[1].path))

                // A new foreground execution window permits uploads again.
                fixture.amplitude.appLifecycle.enterForeground()
                vendor.expireDuringStart = false
                let drained = expectation(description: "explicit flush drains remaining batches")
                client.onUpload = { client.response?(.success(200)) }
                fixture.pipeline.flush { drained.fulfill() }
                wait(for: [drained], timeout: 10)
                XCTAssertEqual(client.uploadCount, succeeds ? 2 : 3)
                XCTAssertEqual(vendor.endCount, client.uploadCount)
                let remaining: [URL] = try XCTUnwrap(storage.read(key: .EVENTS))
                XCTAssertTrue(remaining.isEmpty)
            }
        }
    }

    func testFlushTimerUploadsWhileTrackingIsSuspended() throws {
        let storage = PersistentStorage(storagePrefix: UUID().uuidString, logger: nil,
            diagonostics: Diagnostics(), diagnosticsClient: FakeDiagnosticsClient())
        defer { storage.reset() }
        let config = Configuration(apiKey: "test", flushIntervalMillis: 50,
            instanceName: UUID().uuidString, storageProvider: storage, autocapture: [],
            offline: NetworkConnectivityCheckerPlugin.Disabled, enableAutoCaptureRemoteConfig: false,
            httpClient: RemoteConfigMockServer())
        let delivered = expectation(description: "timer uploads and acknowledges event without tracking")
        config.callback = { _, code, _ in
            XCTAssertEqual(code, 200)
            delivered.fulfill()
        }
        let amplitude = Amplitude(configuration: config)
        amplitude.trackingQueue.sync {}
        amplitude.trackingQueue.suspend()
        defer { amplitude.trackingQueue.resume() }
        try storage.write(key: .EVENTS, value: BaseEvent(eventType: "timer-upload"))
        wait(for: [delivered], timeout: 10)
        let files: [URL] = try XCTUnwrap(storage.read(key: .EVENTS))
        XCTAssertTrue(files.isEmpty)
    }

#if os(macOS) || targetEnvironment(macCatalyst)
    func testDesktopFlushTimerUploadsInBackground() throws {
        let storage = PersistentStorage(storagePrefix: UUID().uuidString, logger: nil,
            diagonostics: Diagnostics(), diagnosticsClient: FakeDiagnosticsClient())
        defer { storage.reset() }
        let config = Configuration(apiKey: "test", flushQueueSize: 100, flushIntervalMillis: 50,
            instanceName: UUID().uuidString, storageProvider: storage, autocapture: [],
            offline: NetworkConnectivityCheckerPlugin.Disabled, enableAutoCaptureRemoteConfig: false,
            httpClient: RemoteConfigMockServer())
        config.flushEventsOnClose = false
        let delivered = expectation(description: "timer uploads below-threshold event in background")
        config.callback = { event, code, _ in
            XCTAssertEqual(event.eventType, "desktop-background-event")
            XCTAssertEqual(code, 200)
            delivered.fulfill()
        }
        let amplitude = Amplitude(configuration: config)
        amplitude.trackingQueue.sync {}
#if os(macOS)
        NotificationCenter.default.post(name: NSApplication.willResignActiveNotification, object: NSApplication.shared)
#else
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
#endif
        amplitude.track(eventType: "desktop-background-event")
        amplitude.trackingQueue.sync {}
        wait(for: [delivered], timeout: 10)
        let files: [URL] = try XCTUnwrap(storage.read(key: .EVENTS))
        XCTAssertTrue(files.isEmpty)
    }
#endif

    func testLifecycleDoesNotRetainPipeline() {
        let amplitude = Amplitude(configuration: configuration)
        weak var observedPipeline: EventPipeline?
        autoreleasepool {
            let pipeline = EventPipeline(amplitude: amplitude)
            observedPipeline = pipeline
        }
        XCTAssertNil(observedPipeline)
    }

    func testInit() {
        XCTAssertEqual(pipeline.configuration.apiKey, configuration.apiKey)
    }

    func testPutEvent() {
        let testEvent = BaseEvent(userId: "unit-test", deviceId: "unit-test-machine", eventType: "testEvent")

        let eventExpectation = expectation(description: "Async function")
        pipeline.put(event: testEvent) {
            eventExpectation.fulfill()
        }
        XCTAssertEqual(testEvent.attempts, 1)

        let waitResult = XCTWaiter.wait(for: [eventExpectation], timeout: 10)
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(pipeline.eventCount, 1)
    }

    func testFlush() throws {
        let testEvent = BaseEvent(userId: "unit-test", deviceId: "unit-test-machine", eventType: "testEvent")
        try? pipeline.storage?.write(key: StorageKey.EVENTS, value: testEvent)

        let flushExpectation = expectation(description: "Async function")
        pipeline.flush {
            flushExpectation.fulfill()
        }
        let waitResult = XCTWaiter.wait(for: [flushExpectation], timeout: 10)
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(httpClient.uploadCount, 1)
        let uploadedEvents = BaseEvent.fromArrayString(jsonString: try XCTUnwrap(httpClient.uploadedEvents.first))
        XCTAssertEqual(uploadedEvents?.count, 1)
        XCTAssertEqual(uploadedEvents?.first?.eventType, "testEvent")
    }

    func testFlushWhenOffline() {
        pipeline.configuration.offline = false

        let testEvent = BaseEvent(userId: "unit-test", deviceId: "unit-test-machine", eventType: "testEvent")
        try? pipeline.storage?.write(key: StorageKey.EVENTS, value: testEvent)

        XCTAssertEqual(httpClient.uploadCount, 0)
        XCTAssertEqual(pipeline.configuration.offline, false)

        pipeline.configuration.offline = true
        pipeline.flush()

        XCTAssertEqual(pipeline.configuration.offline, true)
        XCTAssertEqual(httpClient.uploadCount, 0, "There should be no uploads when offline")
    }

    func testConstructionFailureKeepsQueuedFlushFromStartingAnotherUpload() throws {
        class CountingClient: AnalyticsHttpClient {
            var uploadCount = 0
            var onUpload: (() -> Void)?
            var onResponse: (() -> Void)?
            override func upload(events: String, completion: @escaping (Result<Int, Error>) -> Void) -> (@Sendable () -> Void)? {
                uploadCount += 1
                onUpload?()
                return super.upload(events: events) { result in
                    completion(result)
                    self.onResponse?()
                }
            }
        }
        configuration.serverUrl = "local host"
        configuration.flushMaxRetries = 0
        let amplitude = Amplitude(configuration: configuration)
        let pipeline = EventPipeline(amplitude: amplitude)
        pipeline.stop()
        let client = CountingClient(configuration: configuration, diagnostics: configuration.diagonostics,
            callbackQueue: pipeline.httpClient.callbackQueue, serverZone: amplitude.amplitudeContext.serverZone)
        pipeline.httpClient = client
        let failed = expectation(description: "construction failure processed")
        client.onResponse = { failed.fulfill() }
        client.onUpload = {
            // Queue a second flush before the first upload queues its failure callback.
            if client.uploadCount == 1 { pipeline.flush() }
        }
        try storage.write(key: .EVENTS, value: BaseEvent(eventType: "construction-failure"))
        pipeline.flush()
        wait(for: [failed], timeout: 10)
        XCTAssertEqual(client.uploadCount, 1)
        XCTAssertTrue(configuration.offline == true)

        // Failure processing releases the busy state so a later flush can proceed.
        client.onResponse = nil
        client.onUpload = nil
        configuration.serverUrl = Constants.DEFAULT_API_HOST
        configuration.offline = false
        let drained = expectation(description: "later flush completes")
        pipeline.flush { drained.fulfill() }
        wait(for: [drained], timeout: 10)
        XCTAssertEqual(client.uploadCount, 2)
    }

    func testSimultaneousFlush() throws {
        let testEvent = BaseEvent(userId: "unit-test", deviceId: "unit-test-machine", eventType: "testEvent")
        try? pipeline.storage?.write(key: StorageKey.EVENTS, value: testEvent)

        let httpResponseExpectation = expectation(description: "httpresponse")
        httpClient.uploadExpectations = [httpResponseExpectation]

        let flushExpectations = (0..<2).map { _ in
            let expectation = expectation(description: "flush")
            pipeline.flush {
                expectation.fulfill()
            }
            return expectation
        }

        wait(for: flushExpectations, timeout: 10)
        wait(for: [httpResponseExpectation], timeout: 10)

        XCTAssertEqual(httpClient.uploadCount, 1)
        let uploadedEvents = BaseEvent.fromArrayString(jsonString: try XCTUnwrap(httpClient.uploadedEvents.first))
        XCTAssertEqual(uploadedEvents?.count, 1)
        XCTAssertEqual(uploadedEvents?.first?.eventType, "testEvent")
    }

    func testOneUploadAtATime() throws {
        let fixture = UploadFixture()
        defer { fixture.cleanUp() }
        try fixture.writeBatch(["first"])
        try fixture.writeBatch(["second"])
        let firstStarted = expectation(description: "first request started")
        let secondStarted = expectation(description: "second request started after first response")
        let flushed = expectation(description: "both flushes complete")
        flushed.expectedFulfillmentCount = 2
        fixture.client.onUpload = {
            if fixture.client.uploadCount == 1 {
                firstStarted.fulfill()
            } else {
                secondStarted.fulfill()
            }
        }
        fixture.pipeline.flush { flushed.fulfill() }
        wait(for: [firstStarted], timeout: 10)
        fixture.pipeline.flush { flushed.fulfill() }
        fixture.client.callbackQueue.sync {}
        XCTAssertEqual(fixture.client.uploadCount, 1, "A second flush cannot start a request while the first response is pending")

        fixture.client.response?(.success(200))
        wait(for: [secondStarted], timeout: 10)
        XCTAssertEqual(fixture.client.uploadCount, 2)
        XCTAssertEqual(try fixture.storedEventTypes(), ["second"])
        fixture.client.response?(.success(200))
        wait(for: [flushed], timeout: 10)
        XCTAssertTrue(try fixture.storedEventTypes().isEmpty)
    }

    func testInvalidEventUpload() throws {
        let invalidResponseData = "{\"events_with_invalid_fields\": {\"user_id\": [0]}}".data(using: .utf8)!

        httpClient.uploadResults = [
            .failure(AnalyticsHttpClient.Exception.httpError(code: 400, data: invalidResponseData))
        ]

        let uploadExpectations = (0..<2).map { i in expectation(description: "httpresponse-\(i)") }
        httpClient.uploadExpectations = uploadExpectations

        (0..<2).forEach { i in
            let testEvent = BaseEvent(userId: "test", deviceId: "test-machine", eventType: "testEvent-\(i)")
            try? pipeline.storage?.write(key: StorageKey.EVENTS, value: testEvent)
        }

        let flushExpectation1 = expectation(description: "flush-1")
        pipeline.flush {
            flushExpectation1.fulfill()
        }
        wait(for: [uploadExpectations[0], flushExpectation1], timeout: 10)

        let flushExpectation2 = expectation(description: "flush-2")
        pipeline.flush {
            flushExpectation2.fulfill()
        }
        wait(for: [uploadExpectations[1], flushExpectation2], timeout: 10)

        XCTAssertEqual(httpClient.uploadCount, 2)

        let uploadedEvents0 = BaseEvent.fromArrayString(jsonString: try XCTUnwrap(httpClient.uploadedEvents[safe: 0]))
        XCTAssertEqual(uploadedEvents0?.count, 2)
        XCTAssertEqual(uploadedEvents0?[safe: 0]?.eventType, "testEvent-0")
        XCTAssertEqual(uploadedEvents0?[safe: 1]?.eventType, "testEvent-1")

        let uploadedEvents1 = BaseEvent.fromArrayString(jsonString: try XCTUnwrap(httpClient.uploadedEvents[safe: 1]))
        XCTAssertEqual(uploadedEvents1?.count, 1)
        XCTAssertEqual(uploadedEvents1?[safe: 0]?.eventType, "testEvent-1")
    }

    // test continues to fail until the event is uploaded
    func testContinuousFailure() {
        pipeline.configuration.offline = false
        pipeline.configuration.flushMaxRetries = 2

        let testEvent = BaseEvent(userId: "unit-test", deviceId: "unit-test-machine", eventType: "testEvent")
        try? pipeline.storage?.write(key: StorageKey.EVENTS, value: testEvent)

        let uploadExpectations = (0..<4).map { i in expectation(description: "httpresponse-\(i)") }
        httpClient.uploadExpectations = uploadExpectations

        httpClient.uploadResults = [
            .failure(NSError(domain: "unknown", code: 0, userInfo: nil)), // instant failure
            .failure(NSError(domain: "unknown", code: 0, userInfo: nil)), // +1s failure
            .failure(NSError(domain: "unknown", code: 0, userInfo: nil)), // +2s failure, go offline
            .success(200)
        ]

        pipeline.flush()
        // Expected: upload 0 (instant) + upload 1 (1s retry delay)
        wait(for: [uploadExpectations[0], uploadExpectations[1]], timeout: 15)

        XCTAssertEqual(httpClient.uploadCount, 2)
        XCTAssertEqual(pipeline.configuration.offline, false)

        // Expected: upload 2 (2s retry delay)
        wait(for: [uploadExpectations[2]], timeout: 15)

        XCTAssertEqual(httpClient.uploadCount, 3)
        XCTAssertEqual(pipeline.configuration.offline, true)

        pipeline.configuration.offline = false
        let flushExpectation = expectation(description: "flush")
        pipeline.flush {
            flushExpectation.fulfill()
        }
        wait(for: [uploadExpectations[3], flushExpectation], timeout: 10)

        XCTAssertEqual(httpClient.uploadCount, 4)
    }

    func testFlushSkipsMultipleUnreadableFiles() throws {
        let storeDirectory = storage.getEventsStorageDirectory(createDirectory: false)

        // Clear anything written during Amplitude init (e.g. session_start)
        // so the files below are the only finalized event blocks on disk.
        storage.reset()

        // Create three finalized event files.
        for i in 0..<3 {
            try? pipeline.storage?.write(
                key: StorageKey.EVENTS,
                value: BaseEvent(userId: "u", deviceId: "d", eventType: "marker-\(i)")
            )
            pipeline.storage?.rollover()
        }

        let initialFiles = (try FileManager.default.contentsOfDirectory(at: storeDirectory, includingPropertiesForKeys: nil))
            .filter { $0.pathExtension.isEmpty }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        XCTAssertEqual(initialFiles.count, 3)

        // Corrupt the first two files. The third remains a valid event block.
        let invalidUTF8 = Data([0xFF, 0xFE, 0xFD, 0xFC, 0xC0, 0xC1, 0xF5])
        try invalidUTF8.write(to: initialFiles[0])
        try invalidUTF8.write(to: initialFiles[1])

        let flushExpectation = expectation(description: "flush")
        pipeline.flush {
            flushExpectation.fulfill()
        }
        wait(for: [flushExpectation], timeout: 10)

        // Pipeline must have walked past the two corrupt files and uploaded the third.
        XCTAssertEqual(httpClient.uploadCount, 1, "Pipeline should not stall on corrupt files")
        let uploaded = BaseEvent.fromArrayString(jsonString: try XCTUnwrap(httpClient.uploadedEvents.first))
        XCTAssertEqual(uploaded?.count, 1)
        XCTAssertEqual(uploaded?.first?.eventType, "marker-2")
    }

    func testFlushKeepsSkippingUnreadableFilesAfterUpload() throws {
        // Counts getEventsString invocations per URL so we can catch the
        // regression where skipFiles is dropped after a successful upload,
        // causing quarantine-failed corrupt files to be re-read on each
        // iteration (O(N×M) instead of O(N+M)).
        class CountingStorage: PersistentStorage {
            var readAttempts: [URL: Int] = [:]
            override func getEventsString(eventBlock: URL) -> String? {
                readAttempts[eventBlock, default: 0] += 1
                return super.getEventsString(eventBlock: eventBlock)
            }
        }

        let spyStorage = CountingStorage(
            storagePrefix: "event-pipeline-spy",
            logger: nil,
            diagonostics: Diagnostics(),
            diagnosticsClient: FakeDiagnosticsClient())
        let spyConfiguration = Configuration(
            apiKey: "testApiKey",
            flushIntervalMillis: Int(Self.FLUSH_INTERVAL_SECONDS * 1000),
            storageProvider: spyStorage,
            offline: NetworkConnectivityCheckerPlugin.Disabled,
            httpClient: RemoteConfigMockServer()
        )
        let spyAmplitude = Amplitude(configuration: spyConfiguration)
        let spyHttp = FakeHttpClient(configuration: spyConfiguration, diagnostics: spyConfiguration.diagonostics, serverZone: spyConfiguration.serverZone)
        let spyPipeline = EventPipeline(amplitude: spyAmplitude)
        spyPipeline.httpClient = spyHttp
        spyPipeline.stop()

        let storeDirectory = spyStorage.getEventsStorageDirectory(createDirectory: false)
        // Clear anything written during Amplitude init (e.g. session_start) so
        // we have a clean slate for the interleaved layout below.
        spyStorage.reset()
        spyStorage.readAttempts.removeAll()

        // Layout: [corrupt, good, corrupt, good]. The earlier corrupt file lives
        // to the left of later good files, so if the upload path drops skipFiles
        // on recursion the pipeline re-reads the corrupt file after each good
        // upload.
        for i in 0..<4 {
            try? spyPipeline.storage?.write(
                key: StorageKey.EVENTS,
                value: BaseEvent(userId: "u", deviceId: "d", eventType: "marker-\(i)")
            )
            spyPipeline.storage?.rollover()
        }
        let allFiles = try FileManager.default.contentsOfDirectory(at: storeDirectory, includingPropertiesForKeys: nil)
        let files = allFiles
            .filter { $0.pathExtension.isEmpty }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        XCTAssertEqual(files.count, 4)

        let invalidUTF8 = Data([0xFF, 0xFE, 0xFD, 0xFC, 0xC0, 0xC1, 0xF5])
        try invalidUTF8.write(to: files[0])
        try invalidUTF8.write(to: files[2])

        // Pre-create the quarantine targets for a window of timestamps around
        // "now" so PersistentStorage's moveItem throws NSFileWriteFileExistsError.
        // With quarantine failing, skipFiles must persist across upload recursions
        // or the pipeline re-reads corrupt files once per good upload.
        let quarantineDir = storeDirectory.appendingPathComponent(PersistentStorage.QUARANTINE_DIR_NAME)
        try FileManager.default.createDirectory(at: quarantineDir, withIntermediateDirectories: true)
        let now = Int(Date().timeIntervalSince1970)
        var precreated: [URL] = []
        for delta in -2...10 {
            for corrupt in [files[0], files[2]] {
                let blocker = quarantineDir.appendingPathComponent("\(corrupt.lastPathComponent).\(now + delta)")
                FileManager.default.createFile(atPath: blocker.path, contents: Data())
                precreated.append(blocker)
            }
        }

        let flushExpectation = expectation(description: "flush")
        spyPipeline.flush {
            flushExpectation.fulfill()
        }
        wait(for: [flushExpectation], timeout: 10)

        XCTAssertEqual(spyHttp.uploadCount, 2, "Both good files should upload exactly once")
        let uploaded0 = BaseEvent.fromArrayString(jsonString: try XCTUnwrap(spyHttp.uploadedEvents[safe: 0]))
        let uploaded1 = BaseEvent.fromArrayString(jsonString: try XCTUnwrap(spyHttp.uploadedEvents[safe: 1]))
        XCTAssertEqual(uploaded0?.first?.eventType, "marker-1")
        XCTAssertEqual(uploaded1?.first?.eventType, "marker-3")

        // Quarantine failed → corrupt files remain on disk with original names.
        XCTAssertTrue(FileManager.default.fileExists(atPath: files[0].path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: files[2].path))

        // The key regression assertion: each file is read at most once per flush,
        // regardless of how many good uploads happened between corrupt files.
        // Without skipFiles forwarding, the first corrupt file would be re-read
        // after each good upload (3x total for this layout).
        for (url, count) in spyStorage.readAttempts {
            XCTAssertEqual(count, 1, "File \(url.lastPathComponent) was read \(count) times; expected 1")
        }

        // reset() sweeps the quarantine directory, taking the pre-created blockers with it.
        spyStorage.reset()
        XCTAssertFalse(FileManager.default.fileExists(atPath: quarantineDir.path))
    }

    func testContinuesHandledFailure() {
        pipeline.configuration.offline = false
        pipeline.configuration.flushMaxRetries = 1

        let testEvent1 = BaseEvent(userId: "unit-test", deviceId: "unit-test-machine", eventType: "testEvent")
        try? pipeline.storage?.write(key: StorageKey.EVENTS, value: testEvent1)
        pipeline.storage?.rollover()

        let testEvent2 = BaseEvent(userId: "unit-test", deviceId: "unit-test-machine", eventType: "testEvent")
        try? pipeline.storage?.write(key: StorageKey.EVENTS, value: testEvent2)
        pipeline.storage?.rollover()

        let testEvent3 = BaseEvent(userId: "unit-test", deviceId: "unit-test-machine", eventType: "testEvent")
        try? pipeline.storage?.write(key: StorageKey.EVENTS, value: testEvent3)
        pipeline.storage?.rollover()

        let uploadExpectations = (0..<3).map { i in expectation(description: "httpresponse-\(i)") }
        httpClient.uploadExpectations = uploadExpectations

        let invalidResponseData = "{\"events_with_invalid_fields\": {\"user_id\": [0]}}".data(using: .utf8)!
        httpClient.uploadResults = [
            .failure(AnalyticsHttpClient.Exception.httpError(code: AnalyticsHttpClient.HttpStatus.BAD_REQUEST.rawValue, data: invalidResponseData)),
            .failure(AnalyticsHttpClient.Exception.httpError(code: AnalyticsHttpClient.HttpStatus.PAYLOAD_TOO_LARGE.rawValue, data: nil)),
            .success(200),
        ]

        let flushExpectation = expectation(description: "flush")
        pipeline.flush {
            flushExpectation.fulfill()
        }

        wait(for: uploadExpectations + [flushExpectation], timeout: 10)

        XCTAssertEqual(httpClient.uploadCount, 3)
        XCTAssertEqual(pipeline.configuration.offline, false)
    }
}
